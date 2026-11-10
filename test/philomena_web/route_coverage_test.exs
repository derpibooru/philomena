defmodule PhilomenaWeb.RouteCoverageTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.RouteCoverage

  test "test/route_coverage.txt is in sync with the router" do
    assert File.read!(RouteCoverage.file_path()) == RouteCoverage.rendered(),
           """
           test/route_coverage.txt does not match the router, so a route was
           added, removed, or changed without updating the coverage checklist.

           Regenerate the file (checked marks are preserved) with:

             docker compose exec -T -e MIX_ENV=test app \\
               mix run --no-start -e 'PhilomenaWeb.RouteCoverage.regenerate()'
           """
  end

  test "every route in test/route_coverage.txt is marked [x]" do
    unchecked =
      RouteCoverage.file_path()
      |> File.read!()
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "[ ]"))

    assert unchecked == [],
           """
           #{length(unchecked)} route(s) in test/route_coverage.txt are still
           marked [ ], meaning they have no characterization tests yet:

           #{Enum.join(unchecked, "\n")}

           Every routed action must have characterization tests meeting the
           definition of done (at least one test per auth level that can reach
           the action, plus one failure-path test for write actions). Add those
           tests, then flip the line's [ ] to [x] in test/route_coverage.txt.
           """
  end
end
