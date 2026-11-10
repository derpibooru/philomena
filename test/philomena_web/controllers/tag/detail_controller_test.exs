defmodule PhilomenaWeb.Tag.DetailControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  describe "GET /tags/:tag_id/details" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      tag = tag_fixture()

      conn = get(conn, ~p"/tags/#{tag}/details")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You must log in to access this page."
    end

    test "redirects to / for regular users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture()

      conn = get(conn, ~p"/tags/#{tag}/details")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "renders filter and watcher usage for moderators", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture()

      spoiler_owner = confirmed_user_fixture()
      hide_owner = confirmed_user_fixture()
      spoiler_filter = filter_fixture(spoiler_owner, %{spoilered_tag_list: tag.name})
      hide_filter = filter_fixture(hide_owner, %{hidden_tag_list: tag.name})

      watcher =
        confirmed_user_fixture()
        |> Ecto.Changeset.change(watched_tag_ids: [tag.id])
        |> Repo.update!()

      conn = get(conn, ~p"/tags/#{tag}/details")
      response = html_response(conn, 200)

      assert response =~ "Tag Usage for Tag"
      assert response =~ "Filters that spoiler this tag:"
      assert response =~ "Filters that hide this tag:"
      assert response =~ "Users that watch this tag"
      assert response =~ spoiler_filter.name
      assert response =~ hide_filter.name
      assert response =~ watcher.name
    end

    test "renders empty usage lists for a fresh tag", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture()

      conn = get(conn, ~p"/tags/#{tag}/details")
      response = html_response(conn, 200)

      assert response =~ "Tag Usage for Tag"
      assert response =~ "Users that watch this tag"
    end

    test "redirects with the not-found flash for an unknown tag as moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      # NOTE: the context authorizes the loaded tag on this :index action; an
      # unknown slug loads nil, the moderator is authorized on it, so it
      # redirects instead of dereferencing a nil tag.
      conn = get(conn, ~p"/tags/nonexistent-tag/details")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
