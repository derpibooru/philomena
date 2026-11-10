defmodule PhilomenaWeb.AdvertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AdvertsFixtures

  describe "GET /adverts/:id" do
    test "redirects anonymous users to the advert's external link", %{conn: conn} do
      advert = advert_fixture()

      conn = get(conn, ~p"/adverts/#{advert}")

      # NOTE: the click is recorded asynchronously via Adverts.Server, which
      # is terminated for the test run, so there is no synchronous side
      # effect to assert.
      assert redirected_to(conn) == advert.link
    end

    test "redirects logged-in users to the advert's external link", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      advert = advert_fixture()

      conn = get(conn, ~p"/adverts/#{advert}")

      assert redirected_to(conn) == advert.link
    end

    test "redirects to / for an unknown advert", %{conn: conn} do
      conn = get(conn, ~p"/adverts/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for a disabled advert", %{conn: conn} do
      advert = advert_fixture(%{live: false})

      conn = get(conn, ~p"/adverts/#{advert}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects with the not-found flash for a non-integer advert id", %{conn: conn} do
      conn = get(conn, ~p"/adverts/not-a-number")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
