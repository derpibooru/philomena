defmodule PhilomenaWeb.UserLinkControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.UserLinks

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:user_link) do
    {:ok, user_link} = UserLinks.create_user_link(@create_attrs)
    user_link
  end

  describe "index" do
    test "lists all user_links", %{conn: conn} do
      conn = get(conn, Routes.user_link_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing User links"
    end
  end

  describe "new user_link" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.user_link_path(conn, :new))
      assert html_response(conn, 200) =~ "New User link"
    end
  end

  describe "create user_link" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_link_path(conn, :create), user_link: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.user_link_path(conn, :show, id)

      conn = get(conn, Routes.user_link_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show User link"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_link_path(conn, :create), user_link: @invalid_attrs)
      assert html_response(conn, 200) =~ "New User link"
    end
  end

  describe "edit user_link" do
    setup [:create_user_link]

    test "renders form for editing chosen user_link", %{conn: conn, user_link: user_link} do
      conn = get(conn, Routes.user_link_path(conn, :edit, user_link))
      assert html_response(conn, 200) =~ "Edit User link"
    end
  end

  describe "update user_link" do
    setup [:create_user_link]

    test "redirects when data is valid", %{conn: conn, user_link: user_link} do
      conn = put(conn, Routes.user_link_path(conn, :update, user_link), user_link: @update_attrs)
      assert redirected_to(conn) == Routes.user_link_path(conn, :show, user_link)

      conn = get(conn, Routes.user_link_path(conn, :show, user_link))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, user_link: user_link} do
      conn = put(conn, Routes.user_link_path(conn, :update, user_link), user_link: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit User link"
    end
  end

  describe "delete user_link" do
    setup [:create_user_link]

    test "deletes chosen user_link", %{conn: conn, user_link: user_link} do
      conn = delete(conn, Routes.user_link_path(conn, :delete, user_link))
      assert redirected_to(conn) == Routes.user_link_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.user_link_path(conn, :show, user_link))
      end
    end
  end

  defp create_user_link(_) do
    user_link = fixture(:user_link)
    {:ok, user_link: user_link}
  end
end
