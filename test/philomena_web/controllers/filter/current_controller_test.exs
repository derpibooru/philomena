defmodule PhilomenaWeb.Filter.CurrentControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  alias Philomena.Filters
  alias Philomena.Repo
  alias Philomena.Users.User

  # The filter to switch to comes from the `id` query/body parameter - the
  # route itself is a singleton (`PATCH /filters/current`).

  describe "PATCH /filters/current" do
    test "anonymous users switch via the filter_id cookie", %{conn: conn} do
      filter = Filters.default_filter()

      conn = patch(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Switched to filter #{filter.name}"

      assert conn.resp_cookies["filter_id"].value == Integer.to_string(filter.id)
    end

    test "anonymous users can switch to another user's public filter", %{conn: conn} do
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      conn = patch(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert conn.resp_cookies["filter_id"].value == Integer.to_string(filter.id)
    end

    test "anonymous users are not authorized to switch to unowned private filters",
         %{conn: conn} do
      filter = filter_fixture(confirmed_user_fixture())

      conn = patch(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You can't access that page."
    end

    test "logged-in users switch their account filter", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn = patch(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Switched to filter #{filter.name}"

      reloaded = Repo.get!(User, user.id)
      assert reloaded.current_filter_id == filter.id
      assert filter.id in reloaded.recent_filter_ids
      refute Map.has_key?(conn.resp_cookies, "filter_id")
    end

    test "logged-in users are not authorized to switch to an unowned private filter",
         %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture())
      default = Filters.default_filter()

      conn = patch(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You can't access that page."

      assert Repo.get!(User, user.id).current_filter_id == default.id
    end

    test "an unknown filter id redirects with the not-found flash", %{conn: conn} do
      # NOTE: unlike the :index/:create nil pass-through, the :update action
      # resolves an unknown filter id to not_found, so it redirects with the
      # not-found flash instead of falling back to the default filter.
      conn = patch(conn, ~p"/filters/current?#{[id: 999_999_999]}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "redirects to the referrer when a Referer header is present", %{conn: conn} do
      filter = Filters.default_filter()

      conn =
        conn
        |> put_req_header("referer", "/images")
        |> patch(~p"/filters/current?#{[id: filter.id]}")

      assert redirected_to(conn) == "/images"
    end

    test "PUT also switches the filter", %{conn: conn} do
      filter = Filters.default_filter()

      conn = put(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert conn.resp_cookies["filter_id"].value == Integer.to_string(filter.id)
    end

    test "without an id parameter explicitly switches to the default", %{conn: conn} do
      default = Filters.default_filter()

      conn = patch(conn, ~p"/filters/current")

      assert redirected_to(conn) == "/"
      assert conn.resp_cookies["filter_id"].value == Integer.to_string(default.id)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Switched to filter #{default.name}"
    end

    test "a banned user can still switch filters", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_banned_user(%{conn: conn})
      filter = filter_fixture(user)

      conn = patch(conn, ~p"/filters/current?#{[id: filter.id]}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Switched to filter #{filter.name}"

      assert Repo.get!(User, user.id).current_filter_id == filter.id
    end
  end
end
