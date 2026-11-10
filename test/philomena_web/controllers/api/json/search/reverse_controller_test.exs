defmodule PhilomenaWeb.Api.Json.Search.ReverseControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Reverse search matches against Postgres intensity rows, not OpenSearch,
  # so this module can stay async.

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

  describe "POST /api/v1/json/search/reverse" do
    test "finds images with matching intensities", %{conn: conn} do
      match = image_fixture()
      insert_intensities(match, @png_intensity)

      near_miss = image_fixture()
      insert_intensities(near_miss, @png_intensity + 10)

      conn =
        post(conn, ~p"/api/v1/json/search/reverse", %{"image" => %{"image" => png_upload()}})

      assert %{"images" => [found], "total" => 1, "interactions" => []} =
               json_response(conn, 200)

      assert found["id"] == match.id
    end

    test "returns empty results when nothing matches", %{conn: conn} do
      image = image_fixture()
      insert_intensities(image, @png_intensity + 10)

      conn =
        post(conn, ~p"/api/v1/json/search/reverse", %{"image" => %{"image" => png_upload()}})

      assert json_response(conn, 200) == %{"images" => [], "interactions" => [], "total" => 0}
    end

    test "excludes hidden matching images", %{conn: conn} do
      hidden = image_fixture(hidden_from_users: true)
      insert_intensities(hidden, @png_intensity)

      conn =
        post(conn, ~p"/api/v1/json/search/reverse", %{
          "image" => %{"image" => png_upload()}
        })

      assert json_response(conn, 200) == %{"images" => [], "interactions" => [], "total" => 0}
    end

    test "returns empty results instead of an error for an invalid limit", %{conn: conn} do
      image = image_fixture()
      insert_intensities(image, @png_intensity)

      # NOTE: a changeset-invalid search (limit outside 1..50) is not a 400;
      # it renders a 200 with empty results.
      conn =
        post(conn, ~p"/api/v1/json/search/reverse?limit=999", %{
          "image" => %{"image" => png_upload()}
        })

      assert json_response(conn, 200) == %{"images" => [], "interactions" => [], "total" => 0}
    end

    test "returns empty results when no image is submitted", %{conn: conn} do
      # NOTE: ScraperCachePlug injects an empty "image" params map, so the
      # missing upload surfaces as a failed changeset - again a 200 with
      # empty results, not a 400.
      conn = post(conn, ~p"/api/v1/json/search/reverse")

      assert json_response(conn, 200) == %{"images" => [], "interactions" => [], "total" => 0}
    end
  end
end
