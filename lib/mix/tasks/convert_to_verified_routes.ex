defmodule Mix.Tasks.ConvertToVerifiedRoutes do
  @moduledoc """
  Replaces routes with verified routes.
  Forked from
      https://gist.github.com/andreaseriksson/e454b9244a734310d4ab74d8595f98cd
      https://gist.github.com/jiegillet/e6357c82e36a848ad59295eb3d5a1135

  This requires all routes to consistently be aliased with
      alias PhilomenaWeb.Router.Helpers, as: Routes

  Run with
      mix convert_to_verified_routes
  """

  use Mix.Task

  @regex ~r/(Routes\.)([a-zA-Z0-9_]+)(path|url)\(/
  @web_module PhilomenaWeb

  def run(_) do
    Path.wildcard("test/**/*.ex*")
    |> Enum.concat(Path.wildcard("lib/**/*.ex*"))
    |> Enum.concat(Path.wildcard("lib/**/*.eex*"))
    |> Enum.concat(Path.wildcard("lib/**/*.slime"))
    |> Enum.sort()
    |> Enum.reject(&String.contains?(&1, "convert_to_verified_routes.ex"))
    |> Enum.filter(&(&1 |> File.read!() |> String.contains?("Routes.")))
    |> Enum.each(&format_file/1)

    :ok
  end

  def format_file(filename) do
    Mix.shell().info(filename)

    formatted_content =
      filename
      |> File.read!()
      |> format_string()

    File.write!(filename, [formatted_content])
  end

  def format_string(source) do
    case Regex.run(@regex, source, capture: :first, return: :index) do
      [{index, length}] ->
        # Compute full length of expression
        length = nibble_expression(source, index, length)

        # Convert to verified route format
        route = format_route(String.slice(source, index, length))

        # Split string around expression
        prefix = String.slice(source, 0, index)
        suffix = String.slice(source, index + length, String.length(source))

        # Insert verified route and rerun
        format_string("#{prefix}#{route}#{suffix}")

      _ ->
        source
    end
  end

  defp nibble_expression(source, index, length) do
    if index + length > String.length(source) do
      raise "Failed to match route expression"
    end

    case Code.string_to_quoted(String.slice(source, index, length)) do
      {:ok, _macro} ->
        length

      _ ->
        nibble_expression(source, index, length + 1)
    end
  end

  defp format_route(route) do
    ast =
      Code.string_to_quoted!(route,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        unescape: false,
        token_metadata: true
      )

    ast
    |> Macro.prewalk(&replace_route/1)
    |> Code.quoted_to_algebra(escape: false)
    |> Inspect.Algebra.format(:infinity)
  end

  defp decode_literal(literal) when is_binary(literal) or is_integer(literal) do
    {:ok, literal}
  end

  defp decode_literal({:__block__, _, [literal]}) do
    {:ok, literal}
  end

  defp decode_literal(node), do: {:error, node}

  defp encode_literal(literal) do
    {:__block__, [], [literal]}
  end

  # Routes.url(MyAppWeb.Endpoint)
  defp replace_route({{:., _, [{:__aliases__, _, [:Routes]}, :url]}, _, [_conn_or_endpoint]}) do
    {:url, [], [{:sigil_p, [delimiter: "\""], [{:<<>>, [], ["/"]}, []]}]}
  end

  # Routes.static_path(conn, "/images/favicon.ico")
  defp replace_route({{:., _, [{:__aliases__, _, [:Routes]}, :static_path]}, _, args}) do
    [_conn_or_endpoint, path] = args

    case decode_literal(path) do
      {:ok, path} -> {:sigil_p, [delimiter: "\""], [{:<<>>, [], [path]}, []]}
      _ -> {:sigil_p, [delimiter: "\""], [path, []]}
    end
  end

  # Routes.static_url(conn, "/images/favicon.ico")
  defp replace_route({{:., _, [{:__aliases__, _, [:Routes]}, :static_url]}, _, args}) do
    [_conn_or_endpoint, path] = args

    sigil =
      case decode_literal(path) do
        {:ok, path} -> {:sigil_p, [delimiter: "\""], [{:<<>>, [], [path]}, []]}
        _ -> {:sigil_p, [delimiter: "\""], [path, []]}
      end

    {:url, [], [sigil]}
  end

  # Routes.some_path(conn, :action, "en", query_params)
  defp replace_route(
         {{:., _, [{:__aliases__, _, [:Routes]}, path_name]}, _, [_ | _] = args} = node
       ) do
    [_conn_or_endpoint, action | params] = args

    action =
      case decode_literal(action) do
        {:ok, action} -> action
        _ -> action
      end

    path_name = "#{path_name}"

    case find_verified_route(path_name, action, params) do
      :ok -> node
      route -> route
    end
  end

  defp replace_route(node), do: node

  defp find_verified_route(path_name, action, arguments) do
    # pleaaaase don't have a route named Routes.product_url_path(conn, :index)
    trimmed_path = path_name |> String.trim_trailing("_path") |> String.trim_trailing("_url")

    route =
      Phoenix.Router.routes(@web_module.Router)
      |> Enum.find(fn %{helper: helper, plug_opts: plug_opts} ->
        plug_opts == action && is_binary(helper) && trimmed_path == helper
      end)

    case route do
      %{path: path} ->
        {path_bits, query_params} =
          path
          |> String.split("/", trim: true)
          |> replace_path_variables(arguments, [])

        path_bits =
          path_bits
          |> Enum.flat_map(fn bit -> ["/", bit] end)
          |> format_for_sigil_binary_args(query_params)

        sigil = {:sigil_p, [delimiter: "\""], [{:<<>>, [], path_bits}, []]}

        if String.ends_with?(path_name, "_url") do
          {:url, [], [sigil]}
        else
          sigil
        end

      _ ->
        Mix.shell().error(
          "Could not find route #{path_name}, with action #{inspect(action)} and arguments #{inspect(arguments)}"
        )
    end
  end

  defp replace_path_variables([], arguments, path_bits) do
    {Enum.reverse(path_bits), arguments}
  end

  defp replace_path_variables(path, [], path_bits) do
    {Enum.reverse(path_bits) ++ path, []}
  end

  # conceptually /post/:post_id -> /post/#{id}
  defp replace_path_variables([path_piece | rest], [arg | args], path_bits) do
    if String.starts_with?(path_piece, ":") do
      replace_path_variables(rest, args, [arg | path_bits])
    else
      replace_path_variables(rest, [arg | args], [path_piece | path_bits])
    end
  end

  defp format_for_sigil_binary_args(path_bits, [_ | _] = query_params) do
    format_for_sigil_binary_args(path_bits ++ ["?" | query_params], [])
  end

  defp format_for_sigil_binary_args(path_bits, []) do
    path_bits
    |> Enum.map(&decode_literal/1)
    |> Enum.map(fn
      {:ok, bit} when is_binary(bit) ->
        bit

      {:ok, bit} when is_atom(bit) or is_integer(bit) ->
        to_string(bit)

      {_, bit} ->
        {:"::", [],
         [
           {{:., [], [Kernel, :to_string]}, [from_interpolation: true], [encode_literal(bit)]},
           {:binary, [], Elixir}
         ]}
    end)
  end
end
