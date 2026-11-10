defmodule PhilomenaWeb.Filter.PublicControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  alias Philomena.Filters.Filter
  alias Philomena.Repo

  describe "POST /filters/:filter_id/public" do
    test "makes the owner's filter public", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)
      refute filter.public

      conn = post(conn, ~p"/filters/#{filter}/public")

      assert redirected_to(conn) == ~p"/filters/#{filter}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully made filter public."

      assert Repo.get!(Filter, filter.id).public
    end

    test "an already-public filter succeeds idempotently", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user, %{public: true})

      conn = post(conn, ~p"/filters/#{filter}/public")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully made filter public."
    end

    test "redirects anonymous users with the authorization flash", %{conn: conn} do
      filter = filter_fixture(confirmed_user_fixture())

      conn = post(conn, ~p"/filters/#{filter}/public")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get!(Filter, filter.id).public
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture())

      conn = post(conn, ~p"/filters/#{filter}/public")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get!(Filter, filter.id).public
    end

    test "redirects with the not-found flash for an unknown filter", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/filters/999999999/public")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
