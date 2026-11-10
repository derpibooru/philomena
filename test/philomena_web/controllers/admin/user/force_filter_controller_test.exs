defmodule PhilomenaWeb.Admin.User.ForceFilterControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only.

  import Philomena.UsersFixtures
  import Philomena.FiltersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so forcing/removing a forced filter, and even
  # rendering the force-filter form, is admin-only (or a User-role_map
  # moderator). The plug guards every action here (new/create/delete).

  describe "GET /admin/users/:user_id/force_filter/new" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for an admin", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert html_response(conn, 200) =~ "Forcing filter for user"
    end

    # NOTE: :new is authorized too, so a plain moderator does not even see the
    # force-filter form.
    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the context authorizes the loaded record on :new; an unknown slug
    # loads nil, the admin is authorized on it, so it redirects with the
    # not-found flash rather than passing nil into Users.change_user/1.
    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/users/no-such-user/force_filter/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/users/#{target.slug}/force_filter/new")

      assert html_response(conn, 200) =~ "Forcing filter for user"
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create)" do
    setup [:register_and_log_in_admin]

    test "forces the filter and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Filter was forced"
      assert Repo.get(User, target.id).forced_filter_id == filter.id
    end

    test "re-renders a structured error for a nonexistent forced_filter_id", %{conn: conn} do
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => 2_147_483_647}
        })

      assert html_response(conn, 200) =~ "does not exist"
      refute Repo.get(User, target.id).forced_filter_id
    end

    # NOTE: the context authorizes the loaded record on :create; an unknown slug
    # loads nil, the admin is authorized on it, so it redirects with the
    # not-found flash rather than passing nil into Users.force_filter/2.
    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      conn =
        post(conn, ~p"/admin/users/no-such-user/force_filter", %{
          "user" => %{"forced_filter_id" => 1}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      target = confirmed_user_fixture()

      conn =
        post(without_fingerprint(conn), ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter_fixture(target).id}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get(User, target.id).forced_filter_id
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: no filter was forced
      assert Repo.get(User, target.id).forced_filter_id == nil
    end
  end

  describe "DELETE /admin/users/:user_id/force_filter (delete)" do
    setup [:register_and_log_in_admin]

    test "removes the forced filter and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      target =
        target
        |> User.force_filter_changeset(%{"forced_filter_id" => filter.id})
        |> Repo.update!()

      assert target.forced_filter_id == filter.id

      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Forced filter was removed"
      assert Repo.get(User, target.id).forced_filter_id == nil
    end

    # NOTE: succeeds even when no filter is forced (unforce_filter_changeset just
    # sets forced_filter_id: nil unconditionally).
    test "still succeeds when no filter is forced", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).forced_filter_id == nil
    end

    # NOTE: :delete runs the not_found handler, so an unknown slug redirects.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/force_filter")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/force_filter (delete) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      target =
        target
        |> User.force_filter_changeset(%{"forced_filter_id" => filter.id})
        |> Repo.update!()

      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the forced filter remains in place
      assert Repo.get(User, target.id).forced_filter_id == filter.id
    end
  end
end
