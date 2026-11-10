defmodule PhilomenaWeb.Image.DescriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  test "PATCH as the uploader updates the description and renders the partial",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(%{user_id: user.id})

    conn =
      patch(conn, ~p"/images/#{image}/description", %{
        "image" => %{"description" => "An updated description"}
      })

    response = html_response(conn, 200)

    assert response =~ "An updated description"
    refute response =~ "Derpibooru"
    assert Repo.reload!(image).description == "An updated description"
  end

  test "PUT behaves like PATCH", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(%{user_id: user.id})

    conn =
      put(conn, ~p"/images/#{image}/description", %{
        "image" => %{"description" => "A PUT description"}
      })

    assert html_response(conn, 200) =~ "A PUT description"
    assert Repo.reload!(image).description == "A PUT description"
  end

  test "PATCH with an over-long description re-renders the form", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(%{user_id: user.id, description: "Original description"})

    conn =
      patch(conn, ~p"/images/#{image}/description", %{
        "image" => %{"description" => String.duplicate("a", 50_001)}
      })

    assert html_response(conn, 200)
    assert Repo.reload!(image).description == "Original description"
  end

  test "PATCH as a non-uploader redirects with the authorization flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(%{user_id: confirmed_user_fixture().id})

    conn =
      patch(conn, ~p"/images/#{image}/description", %{
        "image" => %{"description" => "Vandalism"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "PATCH anonymously redirects with the authorization flash", %{conn: conn} do
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/description", %{
        "image" => %{"description" => "Vandalism"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "PATCH as a moderator on someone else's image updates the description", %{conn: conn} do
    %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/description", %{
        "image" => %{"description" => "Moderator edit"}
      })

    assert html_response(conn, 200) =~ "Moderator edit"
    assert Repo.reload!(image).description == "Moderator edit"
  end

  test "PATCH as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = patch(conn, ~p"/images/999999999/description", %{"image" => %{}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end
end
