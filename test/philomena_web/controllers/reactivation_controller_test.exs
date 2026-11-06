defmodule PhilomenaWeb.ReactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Repo
  alias Philomena.Users.UserToken
  alias Philomena.Users
  import Philomena.UsersFixtures

  setup do
    %{user: deactivated_user_fixture()}
  end

  describe "GET /reactivations/:id" do
    test "the emailed link reactivates the account through the rendered form",
         %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_reactivation_instructions(user, url)
        end)

      conn = get(conn, ~p"/reactivations/#{token}")
      response = html_response(conn, 200)
      assert response =~ "<h1>Reactivate Your Account</h1>"

      [_, action, method] =
        Regex.run(
          ~r{<form action="(/reactivations/[^"]+)".*?name="_method"[^>]*value="(\w+)"},
          response
        )

      conn = dispatch(conn, @endpoint, method, action)

      assert redirected_to(conn) == ~p"/"
      assert Users.fetch_user_for_worker!(user.id).deleted_by_user_id == nil
      refute UserToken.user_and_contexts_query(user, ["reactivate"]) |> Repo.exists?()
    end
  end

  describe "PUT /reactivations/:id" do
    test "flashes the same message for an invalid token without reactivating",
         %{conn: conn, user: user} do
      conn = put(conn, ~p"/reactivations/oops")

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If the token provided was valid, your account has been reactivated."

      assert Users.fetch_user_for_worker!(user.id).deleted_by_user_id
    end
  end

  describe "when already logged in" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "GET /reactivations/:id redirects to the homepage", %{conn: conn} do
      conn = get(conn, ~p"/reactivations/some-token")
      assert redirected_to(conn) == "/"
    end

    test "PUT /reactivations/:id redirects to the homepage", %{conn: conn} do
      conn = put(conn, ~p"/reactivations/oops")
      assert redirected_to(conn) == "/"
    end
  end
end
