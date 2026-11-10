defmodule Philomena.ContextBoundaryCheck do
  @moduledoc """
  Static architectural checks for controller and domain-context boundaries.

  The check deliberately uses the Elixir AST instead of text matching so
  comments, documentation examples, and similarly named modules do not create
  false positives. It is used by the context-boundary test in the repository
  test suite.
  """

  @excluded_modules [
    Philomena.Application,
    Philomena.Attribution,
    Philomena.Config,
    Philomena.ExqSupervisor,
    Philomena.IntegerId,
    Philomena.Mailer,
    Philomena.Maintenance,
    Philomena.Markdown,
    Philomena.Multi,
    Philomena.Native,
    Philomena.Release,
    Philomena.Repo,
    Philomena.SearchIndexer,
    Philomena.SearchMigrator,
    Philomena.SearchPolicy,
    Philomena.SiteStatistics,
    Philomena.Slug
  ]

  @type violation :: %{
          file: String.t(),
          line: pos_integer(),
          message: String.t()
        }

  @doc """
  Returns context-boundary violations beneath `root`.

  The check covers every top-level `Philomena` domain module except the
  explicitly excluded infrastructure modules, every `Philomena` domain source
  for direct Canada calls, and every controller for persistence and request-path
  bang-loader calls.

  ## Examples

      iex> ContextBoundaryCheck.violations(File.cwd!())
      []

  """
  @spec violations(String.t()) :: [violation()]
  def violations(root) do
    root
    |> checks()
    |> Enum.sort_by(&{&1.file, &1.line, &1.message})
  end

  defp checks(root) do
    context_paths =
      root
      |> Path.join("lib/philomena/*.ex")
      |> Path.wildcard()
      |> Enum.reject(&excluded_module?/1)

    domain_paths = Path.wildcard(Path.join(root, "lib/philomena/**/*.ex"))
    controller_paths = Path.wildcard(Path.join(root, "lib/philomena_web/controllers/**/*.ex"))

    undocumented_functions(context_paths, root) ++
      forbidden_canada_calls(domain_paths, root) ++
      forbidden_controller_calls(controller_paths, root)
  end

  defp undocumented_functions(paths, root) do
    Enum.flat_map(paths, fn path ->
      path
      |> parse!()
      |> module_bodies()
      |> Enum.flat_map(&undocumented_definitions(&1, relative(path, root)))
    end)
  end

  defp excluded_module?(path) do
    module =
      path
      |> Path.basename(".ex")
      |> Macro.camelize()
      |> then(&Module.concat(Philomena, &1))

    module in @excluded_modules
  end

  defp undocumented_definitions(body, file) do
    body
    |> block_expressions()
    |> Enum.reduce(
      %{documented: MapSet.new(), pending_doc?: false, violations: []},
      fn
        {:@, _meta, [{:doc, _, [_value]}]}, state ->
          %{state | pending_doc?: true}

        {:def, meta, arguments}, state ->
          key = definition_key(arguments)

          cond do
            is_nil(key) ->
              %{state | pending_doc?: false}

            state.pending_doc? or MapSet.member?(state.documented, key) ->
              %{
                state
                | documented: MapSet.put(state.documented, key),
                  pending_doc?: false
              }

            true ->
              {name, arity} = key

              violation = %{
                file: file,
                line: meta[:line] || 1,
                message: "public context function #{name}/#{arity} has no @doc"
              }

              %{state | pending_doc?: false, violations: [violation | state.violations]}
          end

        {:defp, _meta, _arguments}, state ->
          %{state | pending_doc?: false}

        _expression, state ->
          state
      end
    )
    |> Map.fetch!(:violations)
  end

  defp forbidden_canada_calls(paths, root) do
    Enum.flat_map(paths, &canada_violations(&1, root))
  end

  defp canada_violations(path, root) do
    relative_path = relative(path, root)

    if relative_path in [
         "lib/philomena/authorization.ex",
         "lib/philomena/users/ability.ex"
       ] do
      []
    else
      ast = parse!(path)
      aliases = aliases(ast)

      remote_calls(ast, &canada_violation(&1, &2, &3, aliases, relative_path))
    end
  end

  defp canada_violation(module, function, meta, aliases, file) do
    if resolve_module(module, aliases) == "Canada.Can" and function == :can? do
      %{
        file: file,
        line: meta[:line] || 1,
        message: "contexts must call Philomena.Authorization.authorize/3"
      }
    end
  end

  defp forbidden_controller_calls(paths, root) do
    Enum.flat_map(paths, fn path ->
      ast = parse!(path)
      aliases = aliases(ast)
      relative_path = relative(path, root)

      remote_calls(ast, fn module, function, meta ->
        module = resolve_module(module, aliases)

        cond do
          repo_module?(module) ->
            %{
              file: relative_path,
              line: meta[:line] || 1,
              message: "controllers must not call Repo directly"
            }

          context_bang_loader?(module, function) ->
            %{
              file: relative_path,
              line: meta[:line] || 1,
              message: "controllers must not call bang loaders"
            }

          true ->
            nil
        end
      end)
    end)
  end

  # Paths come only from the fixed context inventory and repository-root
  # wildcards assembled by this offline test, never from request input.
  # sobelow_skip ["Traversal.FileModule"]
  defp parse!(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!(columns: true, token_metadata: true)
  end

  defp module_bodies(ast) do
    {_ast, bodies} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _meta, [_module, [do: body]]} = node, bodies ->
          {node, [body | bodies]}

        node, bodies ->
          {node, bodies}
      end)

    bodies
  end

  defp block_expressions({:__block__, _meta, expressions}), do: expressions
  defp block_expressions(expression), do: [expression]

  defp definition_key([head | _body]) do
    head =
      case head do
        {:when, _meta, [guarded_head | _guards]} -> guarded_head
        head -> head
      end

    case head do
      {name, _meta, arguments} when is_atom(name) and is_list(arguments) ->
        {name, length(arguments)}

      {name, _meta, nil} when is_atom(name) ->
        {name, 0}

      _other ->
        nil
    end
  end

  defp definition_key(_arguments), do: nil

  defp aliases(ast) do
    {_ast, aliases} =
      Macro.prewalk(ast, %{}, fn
        {:alias, _meta,
         [
           {{:., _, [prefix_ast, :{}]}, _, module_asts}
         ]} = node,
        aliases ->
          prefix = module_name(prefix_ast)

          aliases =
            Enum.reduce(module_asts, aliases, fn module_ast, aliases ->
              suffix = module_name(module_ast)
              Map.put(aliases, short_name(suffix), prefix <> "." <> suffix)
            end)

          {node, aliases}

        {:alias, _meta, [module_ast, options]} = node, aliases when is_list(options) ->
          module = module_name(module_ast)
          alias_name = options |> Keyword.get(:as, module_ast) |> module_name() |> short_name()
          {node, Map.put(aliases, alias_name, module)}

        {:alias, _meta, [module_ast]} = node, aliases ->
          module = module_name(module_ast)
          {node, Map.put(aliases, short_name(module), module)}

        node, aliases ->
          {node, aliases}
      end)

    aliases
  end

  defp remote_calls(ast, callback) do
    {_ast, violations} =
      Macro.prewalk(ast, [], fn
        {{:., dot_meta, [module_ast, function]}, call_meta, arguments} = node, violations
        when is_atom(function) and is_list(arguments) ->
          case callback.(module_name(module_ast), function, call_meta || dot_meta) do
            nil -> {node, violations}
            violation -> {node, [violation | violations]}
          end

        node, violations ->
          {node, violations}
      end)

    violations
  end

  defp module_name({:__aliases__, _meta, parts}), do: Enum.map_join(parts, ".", &to_string/1)
  defp module_name(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp module_name(_other), do: nil

  defp resolve_module(nil, _aliases), do: nil

  defp resolve_module(module, aliases) do
    case String.split(module, ".", parts: 2) do
      [first, rest] -> Map.get(aliases, first, first) <> "." <> rest
      [first] -> Map.get(aliases, first, first)
    end
  end

  defp short_name(nil), do: nil
  defp short_name(module), do: module |> String.split(".") |> List.last()

  defp repo_module?(nil), do: false
  defp repo_module?(module), do: short_name(module) == "Repo"

  defp context_bang_loader?(module, function) do
    function = Atom.to_string(function)

    is_binary(module) and String.starts_with?(module, "Philomena.") and
      String.ends_with?(function, "!") and
      String.match?(function, ~r/^(fetch|get|load)/)
  end

  defp relative(path, root), do: Path.relative_to(path, root)
end
