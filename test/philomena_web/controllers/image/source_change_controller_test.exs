defmodule PhilomenaWeb.Image.SourceChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Images

  describe "GET /images/:image_id/source_changes" do
    test "lists source changes for anonymous users", %{conn: conn} do
      image = image_fixture()

      {:ok, _result} =
        Images.update_image_sources(actor(nil), image.id, %{
          "old_sources" => %{},
          "sources" => %{"0" => %{"source" => "https://example.com/test-source"}}
        })

      conn = get(conn, ~p"/images/#{image}/source_changes")
      response = html_response(conn, 200)

      assert response =~ "Source Changes on Image #{image.id} - Derpibooru"
      assert response =~ "https://example.com/test-source"
    end

    test "renders with no source changes", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/source_changes")

      assert html_response(conn, 200) =~ "Source Changes on Image #{image.id} - Derpibooru"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with an error flash for an invalid filter", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/source_changes?added=invalid")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid source change filter."
    end
  end
end
