defmodule PhilomenaWeb.Api.Rss.WatchedControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images.Image
  alias Philomena.Repo
  alias Philomena.Users.User
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Image)
    :ok
  end

  defp watch_tag(user, tag) do
    user
    |> User.watched_tags_changeset([tag.id])
    |> Repo.update!()
  end

  describe "GET /api/v1/rss/watched" do
    test "renders an RSS feed of images matching the user's watched tags", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()
      [tag] = image.tags
      _unwatched = image_fixture(tags: "solo")
      watch_tag(user, tag)
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/api/v1/rss/watched?key=#{user.authentication_token}")

      response = response(conn, 200)

      assert response_content_type(conn, :"rss+xml")
      assert response =~ "<title>Derpibooru Watchlist</title>"
      assert response =~ "<title>##{image.id} - safe</title>"
      assert response =~ "/images/#{image.id}</link>"
      refute response =~ "solo"
    end

    test "renders an empty feed for a user with no watched tags", %{conn: conn} do
      user = confirmed_user_fixture()
      _image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/api/v1/rss/watched?key=#{user.authentication_token}")

      response = response(conn, 200)

      assert response =~ "<title>Derpibooru Watchlist</title>"
      refute response =~ "<item>"
    end

    test "redirects an anonymous request with the authorization flash", %{conn: conn} do
      # NOTE: an unauthenticated request gets the browser-style
      # redirect, not a 401.
      conn = get(conn, ~p"/api/v1/rss/watched")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access"
    end
  end
end
