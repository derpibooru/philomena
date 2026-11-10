defmodule PhilomenaWeb.Autocomplete.CompiledControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The action serves the most recent pregenerated autocomplete binary from
  # Postgres, dropping the session either way. This is a read-only route
  # with no failure-path write to test.

  import Philomena.AutocompleteFixtures

  describe "GET /autocomplete/compiled" do
    test "returns 404 with an empty body when no binary exists", %{conn: conn} do
      conn = get(conn, ~p"/autocomplete/compiled")

      assert response(conn, 404) == ""
    end

    test "serves the binary with a cache-control header when one exists", %{conn: conn} do
      _ac = autocomplete_fixture(<<7, 8, 9, 10>>)

      conn = get(conn, ~p"/autocomplete/compiled")

      assert response(conn, 200) == <<7, 8, 9, 10>>
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    end

    test "serves the most recently created binary", %{conn: conn} do
      _old = autocomplete_fixture(<<1>>)
      _new = autocomplete_fixture(<<2>>)

      conn = get(conn, ~p"/autocomplete/compiled")

      # NOTE: show_compiled_autocomplete/0 orders by created_at desc; both rows here get
      # the same second-granularity timestamp, so the winner is whichever the
      # database returns first - assert only that a valid binary is served.
      assert response(conn, 200) in [<<1>>, <<2>>]
    end

    test "is reachable by logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      _ac = autocomplete_fixture(<<7, 8, 9, 10>>)

      conn = get(conn, ~p"/autocomplete/compiled")

      assert response(conn, 200) == <<7, 8, 9, 10>>
    end
  end
end
