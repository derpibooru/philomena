defmodule PhilomenaWeb.Api.Json.ImageControllerTest do
  # async: false - a successful :create spawns a background upload process
  # (Images.async_upload/2) that hits the Repo; it is only allowed on the
  # sandbox connection in shared mode, which ConnCase enables for sync tests.
  use PhilomenaWeb.ConnCase, async: false

  import Philomena.AsyncUpload
  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.RateLimiter
  alias Philomena.ImageFaves
  alias Philomena.Images.Image
  alias Philomena.Repo

  @png_fixture Path.absname("test/support/fixtures/files/upload-test.png")

  setup_all do
    allow_async_uploads()
  end

  describe "GET /api/v1/json/images/:id" do
    test "shows an image with the full representation set", %{conn: conn} do
      image = image_fixture(sources: ["https://example.com/art/1", "https://example.com/art/2"])
      [tag] = image.tags

      conn = get(conn, ~p"/api/v1/json/images/#{image.id}")

      %{year: year, month: month, day: day} = image.created_at

      assert json_response(conn, 200) == %{
               "interactions" => [],
               "image" => %{
                 "id" => image.id,
                 "created_at" => DateTime.to_iso8601(image.created_at),
                 "updated_at" => DateTime.to_iso8601(image.updated_at),
                 "first_seen_at" => DateTime.to_iso8601(image.first_seen_at),
                 "width" => 100,
                 "height" => 100,
                 "mime_type" => "image/png",
                 "size" => 1024,
                 "orig_size" => 1024,
                 "duration" => 0.0,
                 "animated" => false,
                 "format" => "png",
                 "aspect_ratio" => 1.0,
                 "name" => "test.png",
                 "sha512_hash" => image.image_sha512_hash,
                 "orig_sha512_hash" => image.image_orig_sha512_hash,
                 "tags" => ["safe"],
                 "tag_ids" => [tag.id],
                 "tag_count" => 1,
                 "uploader" => nil,
                 "uploader_id" => nil,
                 "wilson_score" => 0,
                 "intensities" => nil,
                 "score" => 0,
                 "upvotes" => 0,
                 "downvotes" => 0,
                 "faves" => 0,
                 "hides" => 0,
                 "comment_count" => 0,
                 "description" => "",
                 "source_url" => "https://example.com/art/1",
                 "source_urls" => [
                   "https://example.com/art/1",
                   "https://example.com/art/2"
                 ],
                 "view_url" => "/img/view/#{year}/#{month}/#{day}/#{image.id}__safe.png",
                 "representations" => %{
                   "thumb_tiny" => "/img/#{year}/#{month}/#{day}/#{image.id}/thumb_tiny.png",
                   "thumb_small" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
                   "thumb" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
                   "small" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
                   "medium" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
                   "large" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
                   "tall" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
                   "full" => "/img/view/#{year}/#{month}/#{day}/#{image.id}.png"
                 },
                 "spoilered" => false,
                 "thumbnails_generated" => true,
                 "processed" => true,
                 "deletion_reason" => nil,
                 "duplicate_of" => nil,
                 "hidden_from_users" => false
               }
             }
    end

    test "attributes the uploader unless the image is anonymous", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture(user_id: user.id)
      anonymous_image = image_fixture(user_id: user.id, anonymous: true)

      conn1 = get(conn, ~p"/api/v1/json/images/#{image.id}")
      body = json_response(conn1, 200)
      assert body["image"]["uploader"] == user.name
      assert body["image"]["uploader_id"] == user.id

      conn2 = get(conn, ~p"/api/v1/json/images/#{anonymous_image.id}")
      body = json_response(conn2, 200)
      assert body["image"]["uploader"] == nil
      assert body["image"]["uploader_id"] == nil
    end

    test "returns a limited object for a hidden image", %{conn: conn} do
      image = image_fixture(hidden_from_users: true, deletion_reason: "Rule #0")

      conn = get(conn, ~p"/api/v1/json/images/#{image.id}")

      body = json_response(conn, 200)
      assert body["image"]["hidden_from_users"] == true
      assert body["image"]["duplicate_id"] == nil
      refute Map.has_key?(body["image"], "tags")
    end

    test "returns a limited object for a merged image",
         %{conn: conn} do
      target = image_fixture()

      image =
        image_fixture(
          hidden_from_users: true,
          deletion_reason: "Duplicate",
          duplicate_id: target.id
        )

      conn = get(conn, ~p"/api/v1/json/images/#{image.id}")

      body = json_response(conn, 200)
      assert body["image"]["hidden_from_users"] == true
      assert body["image"]["duplicate_of"] == target.id
      refute Map.has_key?(body["image"], "tags")
    end

    test "returns the user's interactions with the image for an API key", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()

      {:ok, _} =
        Multi.new()
        |> ImageFaves.put_fave_for_loaded_image(image, user)
        |> Multi.transact()

      conn = get(conn, ~p"/api/v1/json/images/#{image.id}?key=#{user.authentication_token}")

      assert %{"interactions" => interactions, "image" => %{"faves" => 1}} =
               json_response(conn, 200)

      assert interactions == [
               %{
                 "image_id" => image.id,
                 "user_id" => user.id,
                 "interaction_type" => "faved",
                 "value" => ""
               }
             ]
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/images/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/images/not-a-number")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end

  describe "POST /api/v1/json/images" do
    test "creates an image from a direct upload", %{conn: conn} do
      user = confirmed_user_fixture()

      conn =
        conn
        |> put_req_header("user-agent", "Test/1.0")
        |> post(~p"/api/v1/json/images?key=#{user.authentication_token}", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "safe, solo, pony",
            "description" => "An uploaded image"
          }
        })

      assert %{"image" => image, "interactions" => []} = json_response(conn, 200)

      assert %{
               "width" => 1,
               "height" => 1,
               "mime_type" => "image/png",
               "format" => "png",
               "description" => "An uploaded image",
               "processed" => false,
               "thumbnails_generated" => false,
               "uploader" => uploader,
               "uploader_id" => uploader_id
             } = image

      assert uploader == user.name
      assert uploader_id == user.id
      assert Enum.sort(image["tags"]) == ["pony", "safe", "solo"]

      assert %Image{} = Repo.get(Image, image["id"])

      await_async_upload()
    end

    test "returns 400 with changeset errors for invalid tags", %{conn: conn} do
      user = confirmed_user_fixture()

      conn =
        conn
        |> put_req_header("user-agent", "Test/1.0")
        |> post(~p"/api/v1/json/images?key=#{user.authentication_token}", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "solo"
          }
        })

      assert json_response(conn, 400) == %{
               "errors" => %{
                 "tag_input" => [
                   "must contain at least one rating tag",
                   "must contain at least 3 tags"
                 ]
               }
             }
    end

    test "returns 400 when no file is provided", %{conn: conn} do
      user = confirmed_user_fixture()

      conn =
        conn
        |> put_req_header("user-agent", "Test/1.0")
        |> post(~p"/api/v1/json/images?key=#{user.authentication_token}", %{
          "image" => %{"tag_input" => "safe, solo, pony"}
        })

      # NOTE: every analysis-derived field reports "can't be blank", and the
      # image field also carries the corrupt-image message even though no
      # file was sent at all.
      assert json_response(conn, 400) == %{
               "errors" => %{
                 "image" => [
                   "contents corrupt, not recognized, or dimensions are too large to process",
                   "can't be blank"
                 ],
                 "image_aspect_ratio" => ["can't be blank"],
                 "image_duration" => ["can't be blank"],
                 "image_format" => ["can't be blank"],
                 "image_height" => ["can't be blank"],
                 "image_is_animated" => ["can't be blank"],
                 "image_mime_type" => ["can't be blank"],
                 "image_orig_sha512_hash" => ["can't be blank"],
                 "image_orig_size" => ["can't be blank"],
                 "image_sha512_hash" => ["can't be blank"],
                 "image_size" => ["can't be blank"],
                 "image_width" => ["can't be blank"],
                 "uploaded_image" => ["can't be blank"]
               }
             }
    end

    test "creates an image by scraping the url parameter", %{conn: conn} do
      user = confirmed_user_fixture()
      png = File.read!(@png_fixture)

      Req.Test.stub(PhilomenaProxy.Http, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("image/png")
        |> Plug.Conn.resp(200, png)
      end)

      url = "https://example.com/art/upload-test.png"

      conn =
        conn
        |> put_req_header("user-agent", "Test/1.0")
        |> post(~p"/api/v1/json/images?key=#{user.authentication_token}&url=#{url}", %{
          "image" => %{"tag_input" => "safe, solo, pony"}
        })

      assert %{"image" => %{"width" => 1, "height" => 1, "mime_type" => "image/png"}} =
               json_response(conn, 200)

      await_async_upload()
    end

    test "without a User-Agent header the request no longer crashes", %{conn: conn} do
      user = confirmed_user_fixture()

      # NOTE: API attribution now fingerprints a missing User-Agent as crc32("")
      # instead of raising, so a UA-less request proceeds like a normal one;
      # with no url or uploaded file it fails image validation and returns a 400.
      conn =
        post(conn, ~p"/api/v1/json/images?key=#{user.authentication_token}", %{
          "image" => %{"tag_input" => "safe, solo, pony"}
        })

      assert %{"errors" => _} = json_response(conn, 400)
    end

    test "returns 429 once the user exceeds the upload rate limit", %{conn: conn} do
      user = confirmed_user_fixture()
      actor = actor(user)
      :ok = RateLimiter.record_action(actor, :image_create, 5)
      :ok = RateLimiter.record_action(actor, :image_create, 5)

      conn =
        conn
        |> put_req_header("user-agent", "Test/1.0")
        |> post(~p"/api/v1/json/images?key=#{user.authentication_token}", %{
          "image" => %{"image" => png_upload(), "tag_input" => "safe, solo, pony"}
        })

      assert json_response(conn, 429) == %{
               "error" => "You may only upload images once every 5 seconds."
             }
    end

    test "returns 401 with an empty body when no API key is given", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/json/images", %{"image" => %{"tag_input" => "safe"}})

      assert response(conn, 401) == ""
    end

    test "ignores browser session authentication", %{conn: conn} do
      user = confirmed_user_fixture()

      # NOTE: the :api pipeline never fetches the session; only the ?key=
      # parameter authenticates.
      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/api/v1/json/images", %{"image" => %{"tag_input" => "safe"}})

      assert response(conn, 401) == ""
    end

    test "returns 403 with an empty body for a banned user", %{conn: conn} do
      user = banned_user_fixture()

      conn =
        conn
        |> put_req_header("user-agent", "Test/1.0")
        |> post(~p"/api/v1/json/images?key=#{user.authentication_token}", %{
          "image" => %{"tag_input" => "safe, solo, pony"}
        })

      assert response(conn, 403) == ""
    end
  end
end
