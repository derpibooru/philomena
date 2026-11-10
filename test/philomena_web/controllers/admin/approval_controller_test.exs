defmodule PhilomenaWeb.Admin.ApprovalControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  describe "GET /admin/approvals authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/approvals")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/approvals")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/approvals")
      assert html_response(conn, 200) =~ "Approval Queue"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/approvals")
      assert html_response(conn, 200) =~ "Approval Queue"
    end
  end

  describe "GET /admin/approvals (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty queue", %{conn: conn} do
      conn = get(conn, ~p"/admin/approvals")
      response = html_response(conn, 200)
      assert response =~ "Admin - Approval Queue - Derpibooru"
      assert response =~ "Approval Queue"
    end

    test "lists an unapproved image", %{conn: conn} do
      image = image_fixture(approved: false)
      conn = get(conn, ~p"/admin/approvals")
      response = html_response(conn, 200)
      assert response =~ ~p"/images/#{image}"
    end

    test "excludes an approved image", %{conn: conn} do
      approved = image_fixture(approved: true)
      unapproved = image_fixture(approved: false)
      conn = get(conn, ~p"/admin/approvals")
      response = html_response(conn, 200)
      assert response =~ ~p"/images/#{unapproved}"
      refute response =~ ~s(/images/#{approved.id}")
    end
  end
end
