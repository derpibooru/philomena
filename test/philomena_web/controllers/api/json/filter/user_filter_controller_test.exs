defmodule PhilomenaWeb.Api.Json.Filter.UserFilterControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  describe "GET /api/v1/json/filters/user" do
    test "returns 403 with an empty body when anonymous", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/filters/user")

      # NOTE: the 403 body is empty text/plain, unlike the API's JSON 404s.
      assert response(conn, 403) == ""
      assert response_content_type(conn, :text)
    end

    test "returns 403 for an unknown API key", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/filters/user?key=invalid")

      assert response(conn, 403) == ""
    end

    test "returns 403 for a browser session login", %{conn: conn} do
      user = confirmed_user_fixture()

      # NOTE: the :api pipeline never fetches the session; only the ?key=
      # parameter authenticates.
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/v1/json/filters/user")

      assert response(conn, 403) == ""
    end

    test "lists only the authenticated user's filters, ordered by id", %{conn: conn} do
      user = confirmed_user_fixture()
      private = filter_fixture(user, name: "Private Filter")
      public = filter_fixture(user, name: "Public Filter", public: true)

      other = confirmed_user_fixture()
      _other_filter = filter_fixture(other)

      conn = get(conn, ~p"/api/v1/json/filters/user?key=#{user.authentication_token}")

      # NOTE: system filters (including ConnCase's seeded "Default") are
      # excluded - only rows with the user's user_id appear.
      assert json_response(conn, 200) == %{
               "total" => 2,
               "filters" => [
                 %{
                   "id" => private.id,
                   "name" => "Private Filter",
                   "description" => "",
                   "public" => false,
                   "system" => false,
                   "user_count" => 0,
                   "user_id" => user.id,
                   "hidden_tag_ids" => [],
                   "spoilered_tag_ids" => [],
                   "hidden_complex" => "",
                   "spoilered_complex" => ""
                 },
                 %{
                   "id" => public.id,
                   "name" => "Public Filter",
                   "description" => "",
                   "public" => true,
                   "system" => false,
                   "user_count" => 0,
                   "user_id" => user.id,
                   "hidden_tag_ids" => [],
                   "spoilered_tag_ids" => [],
                   "hidden_complex" => "",
                   "spoilered_complex" => ""
                 }
               ]
             }
    end

    test "returns an empty list for a user with no filters", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/api/v1/json/filters/user?key=#{user.authentication_token}")

      assert json_response(conn, 200) == %{"filters" => [], "total" => 0}
    end

    test "supports page and per_page parameters", %{conn: conn} do
      user = confirmed_user_fixture()
      _first = filter_fixture(user)
      second = filter_fixture(user)

      conn =
        get(
          conn,
          ~p"/api/v1/json/filters/user?key=#{user.authentication_token}&per_page=1&page=2"
        )

      assert %{"total" => 2, "filters" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == second.id
    end

    test "returns 403 for an unconfirmed user's API key", %{conn: conn} do
      user = user_fixture()

      # NOTE: EnsureUserEnabledPlug now returns 403 with an empty text/plain body
      # on the :api pipeline instead of raising (it no longer touches the
      # unfetched session/flash).
      conn = get(conn, ~p"/api/v1/json/filters/user?key=#{user.authentication_token}")

      assert response(conn, 403) == ""
    end

    test "returns 403 for a deactivated user's API key", %{conn: conn} do
      user = deactivated_user_fixture()

      conn = get(conn, ~p"/api/v1/json/filters/user?key=#{user.authentication_token}")

      assert response(conn, 403) == ""
    end
  end
end
