defmodule PhilomenaWeb.Search.ReverseControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Reverse search matches against Postgres intensity rows, not OpenSearch,
  # so this module can stay async. GET /search/reverse (index) simply
  # delegates to create/2.

  # png_upload/0 hands the pipeline a tempfile copy of the fixture: Remote.cmd/2
  # round-trips every absolute path argument through mediaproc, which writes the
  # returned bytes back over the original path. Pointing at the tracked fixture
  # corrupts the working tree.
  import Philomena.ImagesFixtures

  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.Repo

  # Intensities of the 1x1 fixture PNG, as computed by the media processor.
  @png_intensity 54.213

  defp insert_intensities(image, value) do
    Repo.insert!(%ImageIntensity{image_id: image.id, nw: value, ne: value, sw: value, se: value})
  end

  describe "GET /search/reverse" do
    test "renders the reverse search form for anonymous users", %{conn: conn} do
      conn = get(conn, ~p"/search/reverse")
      response = html_response(conn, 200)

      assert response =~ "Reverse Search"
      # No upload submitted: images assigns nil, so neither the result list nor
      # the "No images found!" message renders.
      refute response =~ "No images found!"
    end

    test "renders the reverse search form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/search/reverse")

      assert html_response(conn, 200) =~ "Reverse Search"
    end
  end

  describe "POST /search/reverse" do
    test "renders matching images for anonymous users", %{conn: conn} do
      match = image_fixture()
      insert_intensities(match, @png_intensity)

      near_miss = image_fixture()
      insert_intensities(near_miss, @png_intensity + 10)

      conn = post(conn, ~p"/search/reverse", %{"image" => %{"image" => png_upload()}})
      response = html_response(conn, 200)

      assert response =~ "Reverse Search"
      assert response =~ ~p"/images/#{match}"
      refute response =~ ~p"/images/#{near_miss}"
    end

    test "renders 'No images found!' when nothing matches", %{conn: conn} do
      image = image_fixture()
      insert_intensities(image, @png_intensity + 10)

      conn = post(conn, ~p"/search/reverse", %{"image" => %{"image" => png_upload()}})
      response = html_response(conn, 200)

      assert response =~ "No images found!"
      refute response =~ ~p"/images/#{image}"
    end

    test "renders matches with interactions for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      match = image_fixture()
      insert_intensities(match, @png_intensity)

      conn = post(conn, ~p"/search/reverse", %{"image" => %{"image" => png_upload()}})

      assert html_response(conn, 200) =~ ~p"/images/#{match}"
    end

    test "filters hidden matches by image visibility", %{conn: conn} do
      visible = image_fixture()
      insert_intensities(visible, @png_intensity)

      hidden = image_fixture(hidden_from_users: true)
      insert_intensities(hidden, @png_intensity)

      conn = post(conn, ~p"/search/reverse", %{"image" => %{"image" => png_upload()}})
      response = html_response(conn, 200)

      assert response =~ ~p"/images/#{visible}"
      refute response =~ ~p"/images/#{hidden}"

      %{conn: moderator_conn} = register_and_log_in_moderator(%{conn: build_conn()})

      moderator_conn =
        post(moderator_conn, ~p"/search/reverse", %{
          "image" => %{"image" => png_upload()}
        })

      assert html_response(moderator_conn, 200) =~ ~p"/images/#{hidden}"
    end

    test "renders the plain form when no image is submitted", %{conn: conn} do
      # NOTE: ScraperCachePlug injects an empty "image" params map, so a submit
      # with no upload takes the third create/2 clause and renders the form
      # with images: nil - a 200, not a validation error, and no
      # "No images found!" message.
      conn = post(conn, ~p"/search/reverse")
      response = html_response(conn, 200)

      assert response =~ "Reverse Search"
      refute response =~ "No images found!"
    end

    test "renders the plain form for an invalid distance", %{conn: conn} do
      image = image_fixture()
      insert_intensities(image, @png_intensity)

      # NOTE: a changeset-invalid search (distance is normalized but the query
      # still fails to analyze without a real upload here) renders 200 with the
      # form, not a 400.
      conn =
        post(conn, ~p"/search/reverse?distance=abc", %{"image" => %{"image" => png_upload()}})

      assert html_response(conn, 200) =~ "Reverse Search"
    end
  end
end
