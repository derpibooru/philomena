defmodule PhilomenaWeb.RouteCoverage do
  @moduledoc """
  Source of truth for `test/route_coverage.txt`, the checklist tracking
  characterization-test coverage of every routed controller action.

  The checklist is kept in sync with the router by
  `test/philomena_web/route_coverage_test.exs`. After changing the router,
  regenerate it - existing `[x]` marks are preserved - with:

      docker compose exec -T -e MIX_ENV=test app \\
        mix run --no-start -e 'PhilomenaWeb.RouteCoverage.regenerate()'
  """

  @doc "Absolute path to the checklist file."
  def file_path do
    Path.expand("../route_coverage.txt", __DIR__)
  end

  @doc """
  Every route in the router, in declaration order, as
  `{verb, path, controller, action}` display strings.
  """
  def routes do
    PhilomenaWeb.Router
    |> Phoenix.Router.routes()
    |> Enum.map(fn %{verb: verb, path: path, plug: plug, plug_opts: action} ->
      {
        verb |> Atom.to_string() |> String.upcase(),
        path,
        plug |> inspect() |> String.replace_prefix("PhilomenaWeb.", ""),
        ":#{action}"
      }
    end)
  end

  @doc """
  The canonical checklist content: one line per route, carrying over `[x]`
  marks from the current file for routes that still exist.
  """
  def rendered do
    marks = existing_marks()
    routes = routes()

    verb_width = routes |> Enum.map(&String.length(elem(&1, 0))) |> Enum.max()
    path_width = routes |> Enum.map(&String.length(elem(&1, 1))) |> Enum.max()

    lines =
      Enum.map(routes, fn {verb, path, controller, action} = route ->
        mark = if MapSet.member?(marks, route), do: "x", else: " "

        "[#{mark}] #{String.pad_trailing(verb, verb_width)} " <>
          "#{String.pad_trailing(path, path_width)} #{controller} #{action}"
      end)

    header() <> Enum.join(lines, "\n") <> "\n"
  end

  @doc "Writes the canonical checklist to `file_path()`."
  def regenerate do
    File.write!(file_path(), rendered())
  end

  defp existing_marks do
    case File.read(file_path()) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.flat_map(fn line ->
          case Regex.run(~r/^\[x\] (\S+) +(\S+) +(\S+) +(:\S+)$/, line) do
            [_, verb, path, controller, action] -> [{verb, path, controller, action}]
            _ -> []
          end
        end)
        |> MapSet.new()

      {:error, _} ->
        MapSet.new()
    end
  end

  defp header do
    """
    # Characterization-test route coverage checklist. See test/CONVENTIONS.md.
    #
    # [x] means the route meets the characterization definition of done:
    # at least one test per auth level that can reach the action, plus one
    # failure-path test for write actions. Flip
    # marks by hand as tests land. After router changes, regenerate the file
    # (marks are preserved) with:
    #
    #   docker compose exec -T -e MIX_ENV=test app \\
    #     mix run --no-start -e 'PhilomenaWeb.RouteCoverage.regenerate()'
    #
    """
  end
end
