defmodule PhilomenaWeb.Channel.NsfwControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The controller only sets/clears the JS-readable `chan_nsfw` cookie and
  # redirects to /channels; it never touches the database and has no
  # failure surface (it always succeeds), so there is no failure-path test.

  describe "POST /channels/nsfw" do
    test "sets chan_nsfw=true and redirects for anonymous users", %{conn: conn} do
      conn = post(conn, ~p"/channels/nsfw")

      assert redirected_to(conn) == ~p"/channels"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Successfully updated channel visibility."

      cookie = conn.resp_cookies["chan_nsfw"]
      assert cookie.value == "true"
      # NOTE: the cookie is deliberately JS-readable (http_only: false),
      # SameSite=Lax, with a ~25-year max-age.
      assert cookie.http_only == false
      assert cookie.max_age == 788_923_800
      assert cookie.extra == "SameSite=Lax"
    end

    test "sets chan_nsfw=true for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/channels/nsfw")

      assert redirected_to(conn) == ~p"/channels"
      assert conn.resp_cookies["chan_nsfw"].value == "true"
    end
  end

  describe "DELETE /channels/nsfw" do
    test "sets chan_nsfw=false and redirects for anonymous users", %{conn: conn} do
      conn = delete(conn, ~p"/channels/nsfw")

      assert redirected_to(conn) == ~p"/channels"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Successfully updated channel visibility."

      cookie = conn.resp_cookies["chan_nsfw"]
      # NOTE: "off" is represented by an explicit "false" value cookie, not by
      # deleting the cookie.
      assert cookie.value == "false"
      assert cookie.max_age == 788_923_800
    end

    test "sets chan_nsfw=false for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/channels/nsfw")

      assert redirected_to(conn) == ~p"/channels"
      assert conn.resp_cookies["chan_nsfw"].value == "false"
    end
  end
end
