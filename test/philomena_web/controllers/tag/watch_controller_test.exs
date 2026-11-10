defmodule PhilomenaWeb.Tag.WatchControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.TagsFixtures

  alias Philomena.Repo
  alias Philomena.Tags

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/tags/dummy-slug/watch")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "anonymous DELETE redirects to the login page", %{conn: conn} do
    conn = delete(conn, ~p"/tags/dummy-slug/watch")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "POST adds the tag to the user's watched tags and responds 200 with an empty body",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    tag = tag_fixture()

    conn = post(conn, ~p"/tags/#{tag}/watch")

    assert response(conn, 200) == ""
    assert Repo.reload!(user).watched_tag_ids == [tag.id]
  end

  test "POST when already watching keeps a single entry", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    tag = tag_fixture()
    {:ok, _} = Tags.create_tag_watch(actor(user), tag.slug)

    conn = post(conn, ~p"/tags/#{tag}/watch")

    assert response(conn, 200) == ""
    assert Repo.reload!(user).watched_tag_ids == [tag.id]
  end

  test "DELETE removes the tag from the user's watched tags", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    tag = tag_fixture()
    {:ok, _} = Tags.create_tag_watch(actor(user), tag.slug)

    conn = delete(conn, ~p"/tags/#{tag}/watch")

    assert response(conn, 200) == ""
    assert Repo.reload!(user).watched_tag_ids == []
  end

  test "DELETE when not watching still responds 200", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    tag = tag_fixture()

    conn = delete(conn, ~p"/tags/#{tag}/watch")

    assert response(conn, 200) == ""
    assert Repo.reload!(user).watched_tag_ids == []
  end

  test "banned users can update their watched tags", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_banned_user(%{conn: conn})
    tag = tag_fixture()

    conn = post(conn, ~p"/tags/#{tag}/watch")

    assert response(conn, 200) == ""
    assert Repo.reload!(user).watched_tag_ids == [tag.id]
  end

  test "POST for an unknown tag redirects with the not-found flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/tags/unknown-slug/watch")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
