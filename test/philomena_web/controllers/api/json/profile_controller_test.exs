defmodule PhilomenaWeb.Api.Json.ProfileControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BadgesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  describe "GET /api/v1/json/profiles/:id" do
    test "shows a user profile", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/api/v1/json/profiles/#{user.id}")

      assert json_response(conn, 200) == %{
               "user" => %{
                 "id" => user.id,
                 "name" => user.name,
                 "slug" => user.slug,
                 "role" => "user",
                 "description" => nil,
                 "avatar_url" => nil,
                 "created_at" => DateTime.to_iso8601(user.created_at),
                 "comments_count" => 0,
                 "uploads_count" => 0,
                 "posts_count" => 0,
                 "topics_count" => 0,
                 "links" => [],
                 "awards" => []
               }
             }
    end

    test "renders badge awards", %{conn: conn} do
      admin = admin_user_fixture()
      user = confirmed_user_fixture()
      badge = badge_fixture(title: "Artist")
      award = badge_award_fixture(admin, user, badge)

      conn = get(conn, ~p"/api/v1/json/profiles/#{user.id}")

      assert %{"user" => %{"awards" => awards}} = json_response(conn, 200)

      assert awards == [
               %{
                 "id" => badge.id,
                 "title" => "Artist",
                 "label" => award.label,
                 "image_url" => "/badge-img/test.svg",
                 "awarded_on" => DateTime.to_iso8601(award.awarded_on)
               }
             ]
    end

    test "shows staff roles", %{conn: conn} do
      moderator = moderator_user_fixture()

      conn = get(conn, ~p"/api/v1/json/profiles/#{moderator.id}")

      assert %{"user" => %{"role" => "moderator"}} = json_response(conn, 200)
    end

    test "masks the role of staff hiding their default role", %{conn: conn} do
      moderator =
        moderator_user_fixture()
        |> Ecto.Changeset.change(hide_default_role: true)
        |> Repo.update!()

      conn = get(conn, ~p"/api/v1/json/profiles/#{moderator.id}")

      assert %{"user" => %{"role" => "user"}} = json_response(conn, 200)
    end

    test "returns 404 for a deactivated user", %{conn: conn} do
      user = deactivated_user_fixture()

      conn = get(conn, ~p"/api/v1/json/profiles/#{user.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/profiles/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/profiles/not-a-number")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
