defmodule PhilomenaWeb.Filter.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.TagsFixtures

  alias Philomena.Filters
  alias Philomena.Repo
  alias Philomena.Users

  # The tag comes from the `tag` query parameter - this is a singleton
  # route on the *current* filter, not a nested tag route.

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/filters/hide?tag=dummy-slug")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "anonymous DELETE redirects to the login page", %{conn: conn} do
    conn = delete(conn, ~p"/filters/hide?tag=dummy-slug")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "banned users are redirected back with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = post(conn, ~p"/filters/hide?tag=dummy-slug")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
  end

  test "POST with the default system filter current responds 403 with an empty body",
       %{conn: conn} do
    # NOTE: a fresh user's current filter is the system default, which they
    # cannot edit, so hiding a tag silently fails until they switch to a
    # filter of their own.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    tag = tag_fixture()

    path = ~p"/filters/hide?#{[tag: tag.slug]}"
    conn = post(conn, path)

    assert response(conn, 403) == ""
  end

  test "POST hides the tag on the user's own current filter", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    filter = filter_fixture(user)
    {:ok, _} = Users.set_current_filter(user, filter)
    tag = tag_fixture()

    path = ~p"/filters/hide?#{[tag: tag.slug]}"
    conn = post(conn, path)

    assert response(conn, 200) == ""
    assert Repo.reload!(filter).hidden_tag_ids == [tag.id]
  end

  test "DELETE unhides the tag on the user's own current filter", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    filter = filter_fixture(user)
    {:ok, _} = Users.set_current_filter(user, filter)
    tag = tag_fixture()

    {:ok, _} =
      Filters.create_filter_hide(Philomena.AttributionFixtures.actor(user), filter, tag.slug)

    path = ~p"/filters/hide?#{[tag: tag.slug]}"
    conn = delete(conn, path)

    assert response(conn, 200) == ""
    assert Repo.reload!(filter).hidden_tag_ids == []
  end

  test "POST for an unknown tag redirects with the not-found flash", %{conn: conn} do
    # The context authorizes the current filter before safely loading the tag,
    # so an unknown slug returns the normalized not-found result.
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    {:ok, _} = Users.set_current_filter(user, filter_fixture(user))

    conn = post(conn, ~p"/filters/hide?tag=unknown-slug")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
