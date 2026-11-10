defmodule PhilomenaWeb.Api.Json.FilterControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  describe "GET /api/v1/json/filters/:id" do
    test "shows a system filter to anonymous users", %{conn: conn} do
      filter = system_filter_fixture(name: "Everything", description: "Contains no filtering")

      conn = get(conn, ~p"/api/v1/json/filters/#{filter}")

      assert json_response(conn, 200) == %{
               "filter" => %{
                 "id" => filter.id,
                 "name" => "Everything",
                 "description" => "Contains no filtering",
                 "public" => false,
                 "system" => true,
                 "user_count" => 0,
                 "user_id" => nil,
                 "hidden_tag_ids" => [],
                 "spoilered_tag_ids" => [],
                 "hidden_complex" => "",
                 "spoilered_complex" => ""
               }
             }
    end

    test "shows another user's public filter to anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      filter = filter_fixture(user, public: true)

      conn = get(conn, ~p"/api/v1/json/filters/#{filter}")

      assert %{"filter" => %{"public" => true, "user_id" => user_id}} =
               json_response(conn, 200)

      assert user_id == user.id
    end

    test "returns 404 for a private filter when anonymous", %{conn: conn} do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      conn = get(conn, ~p"/api/v1/json/filters/#{filter}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a nonexistent filter id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/filters/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "shows a private filter to its owner authenticated by API key", %{conn: conn} do
      user = confirmed_user_fixture()
      filter = filter_fixture(user, name: "My secrets")

      conn = get(conn, ~p"/api/v1/json/filters/#{filter}?key=#{user.authentication_token}")

      assert %{"filter" => %{"name" => "My secrets", "public" => false}} =
               json_response(conn, 200)
    end

    test "returns 404 for another user's private filter even with a valid API key", %{conn: conn} do
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      filter = filter_fixture(owner)

      conn = get(conn, ~p"/api/v1/json/filters/#{filter}?key=#{other.authentication_token}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "shows any private filter to a moderator", %{conn: conn} do
      owner = confirmed_user_fixture()
      filter = filter_fixture(owner)

      moderator =
        confirmed_user_fixture()
        |> Ecto.Changeset.change(role: "moderator")
        |> Repo.update!()

      conn = get(conn, ~p"/api/v1/json/filters/#{filter}?key=#{moderator.authentication_token}")

      assert %{"filter" => %{"id" => id}} = json_response(conn, 200)
      assert id == filter.id
    end

    test "ignores browser session authentication", %{conn: conn} do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      # NOTE: the :api pipeline never fetches the session; only the ?key=
      # parameter authenticates, so the filter's owner still gets a 404.
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/v1/json/filters/#{filter}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a non-integer id", %{conn: conn} do
      # NOTE: the id is now parsed first, so a non-integer id 404s like an
      # unknown id rather than raising a cast error.
      conn = get(conn, ~p"/api/v1/json/filters/not-a-number")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
