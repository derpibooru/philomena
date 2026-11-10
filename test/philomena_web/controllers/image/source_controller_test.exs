defmodule PhilomenaWeb.Image.SourceControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ImagesFixtures

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Repo

  test "PATCH as a logged-in user updates the sources and renders the partial",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/sources", %{
        "image" => %{
          "old_sources" => %{},
          "sources" => %{"0" => %{"source" => "https://example.com/new-source"}}
        }
      })

    response = html_response(conn, 200)

    assert response =~ "https://example.com/new-source"
    refute response =~ "Derpibooru"

    assert Repo.exists?(
             from sc in SourceChange,
               where: sc.image_id == ^image.id and sc.user_id == ^user.id
           )
  end

  test "PUT behaves like PATCH", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      put(conn, ~p"/images/#{image}/sources", %{
        "image" => %{
          "old_sources" => %{},
          "sources" => %{"0" => %{"source" => "https://example.com/put-source"}}
        }
      })

    assert html_response(conn, 200) =~ "https://example.com/put-source"
  end

  test "PATCH with an invalid source URL re-renders the existing image", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(sources: ["https://example.com/existing-source"])

    conn =
      patch(conn, ~p"/images/#{image}/sources", %{
        "image" => %{
          "old_sources" => %{},
          "sources" => %{"0" => %{"source" => "not-a-url"}}
        }
      })

    response = html_response(conn, 200)

    assert response =~ "https://example.com/existing-source"
    assert response =~ "not-a-url"
    assert response =~ "has invalid format"
    refute Repo.exists?(from sc in SourceChange, where: sc.image_id == ^image.id)
  end

  test "PATCH anonymously updates the sources", %{conn: conn} do
    image = image_fixture()

    conn =
      conn
      |> put_unique_ip()
      |> patch(~p"/images/#{image}/sources", %{
        "image" => %{
          "old_sources" => %{},
          "sources" => %{"0" => %{"source" => "https://example.com/anon-source"}}
        }
      })

    assert html_response(conn, 200) =~ "https://example.com/anon-source"

    assert Repo.exists?(
             from sc in SourceChange,
               where: sc.image_id == ^image.id and is_nil(sc.user_id)
           )
  end

  test "PATCH with more than 15 sources renders the form with the changeset error",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    sources =
      Map.new(0..15, fn i -> {"#{i}", %{"source" => "https://example.com/source-#{i}"}} end)

    conn =
      patch(conn, ~p"/images/#{image}/sources", %{
        "image" => %{"old_sources" => %{}, "sources" => sources}
      })

    assert html_response(conn, 200)
    refute Repo.exists?(from sc in SourceChange, where: sc.image_id == ^image.id)
  end

  test "PATCH on a hidden image redirects with the authorization flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(hidden_from_users: true)

    conn =
      patch(conn, ~p"/images/#{image}/sources", %{
        "image" => %{
          "old_sources" => %{},
          "sources" => %{"0" => %{"source" => "https://example.com/new-source"}}
        }
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "PATCH as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = patch(conn, ~p"/images/999999999/sources", %{"image" => %{}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end
end
