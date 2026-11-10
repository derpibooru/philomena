defmodule PhilomenaWeb.Api.Json.Filter.SystemFilterControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  alias Philomena.Filters

  describe "GET /api/v1/json/filters/system" do
    test "lists the default system filter", %{conn: conn} do
      # NOTE: ConnCase inserts the "Default" system filter before every test,
      # so the index is never empty.
      default = Filters.default_filter()

      conn = get(conn, ~p"/api/v1/json/filters/system")

      assert json_response(conn, 200) == %{
               "total" => 1,
               "filters" => [
                 %{
                   "id" => default.id,
                   "name" => "Default",
                   "description" => "",
                   "public" => false,
                   "system" => true,
                   "user_count" => 0,
                   "user_id" => nil,
                   "hidden_tag_ids" => [],
                   "spoilered_tag_ids" => [],
                   "hidden_complex" => "",
                   "spoilered_complex" => ""
                 }
               ]
             }
    end

    test "lists system filters ordered by id, excluding user filters", %{conn: conn} do
      default = Filters.default_filter()
      extra = system_filter_fixture(name: "Maximum Spoilers")

      user = confirmed_user_fixture()
      _public = filter_fixture(user, public: true)
      _private = filter_fixture(user)

      conn = get(conn, ~p"/api/v1/json/filters/system")

      assert %{"total" => 2, "filters" => filters} = json_response(conn, 200)
      assert Enum.map(filters, & &1["id"]) == [default.id, extra.id]
      assert Enum.map(filters, & &1["name"]) == ["Default", "Maximum Spoilers"]
    end

    test "supports page and per_page parameters", %{conn: conn} do
      extra = system_filter_fixture(name: "Second Filter")

      conn = get(conn, ~p"/api/v1/json/filters/system?per_page=1&page=2")

      # NOTE: "total" is the total number of rows, not the page size.
      assert %{"total" => 2, "filters" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == extra.id
    end

    test "responds identically for API key authenticated users", %{conn: conn} do
      user = confirmed_user_fixture()
      default = Filters.default_filter()

      conn = get(conn, ~p"/api/v1/json/filters/system?key=#{user.authentication_token}")

      assert %{"total" => 1, "filters" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == default.id
    end
  end
end
