defmodule PhilomenaWeb.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.AsyncUpload
  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Comments
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  alias Philomena.Roles.Role

  setup_all do
    allow_async_uploads()
  end

  setup do
    Search.clear_index!(Image)
    # :show and :new render the quick tag table, which queries the tags index
    # (TagView.lookup_quick_tags/1) the first time it is built in a test run.
    Search.clear_index!(Tag)
    :ok
  end

  defp assistant_with_image_role do
    assistant = Philomena.UsersFixtures.assistant_user_fixture()
    role = Repo.insert!(%Role{name: "moderator", resource_type: "Image"})
    Repo.insert_all("users_roles", [%{user_id: assistant.id, role_id: role.id}])
    assistant
  end

  describe "GET /images" do
    test "lists images for anonymous users", %{conn: conn} do
      image = image_fixture(created_at: hours_ago(1))
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      assert response =~ "Images - Derpibooru"
      assert response =~ ~p"/images/#{image.id}"
    end

    # NOTE: ImageLoader.default_query hides images uploaded less than three
    # minutes ago from anonymous users (delay_home_images?/1).
    test "hides just-uploaded images from anonymous users", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      refute response =~ ~p"/images/#{image.id}"
    end

    # NOTE: the delay also applies to logged-in users by default
    # (User.delay_home_images defaults to true).
    test "hides just-uploaded images from logged-in users with default settings", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      refute response =~ ~p"/images/#{image.id}"
    end

    test "shows just-uploaded images to users who disabled the upload delay", %{conn: conn} do
      user = confirmed_user_fixture()

      user.settings
      |> Ecto.Changeset.change(delay_home_images: false)
      |> Repo.update!()

      conn = log_in_user(conn, user)

      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      assert response =~ ~p"/images/#{image.id}"
    end
  end

  describe "GET /images/:id" do
    test "renders an image for anonymous users", %{conn: conn} do
      image = image_fixture(description: "An image *described* in markdown.")
      _comment = comment_fixture(image, nil, %{"body" => "Test image comment body"})

      conn = get(conn, ~p"/images/#{image}")
      response = html_response(conn, 200)

      assert response =~ "##{image.id} - safe - Derpibooru"
      assert response =~ "An image <em>described</em> in markdown."
      assert response =~ "Test image comment body"
    end

    test "renders a hidden comment's deletion reason but not its body to anonymous users",
         %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Hidden image comment body"})

      {:ok, _} =
        Comments.create_comment_hide(
          actor(moderator_user_fixture()),
          image.id,
          comment.id,
          %{"deletion_reason" => "Off-topic comment"}
        )

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ "Deletion reason:"
      assert response =~ "Off-topic comment"
      refute response =~ "Hidden image comment body"
    end

    test "renders an image for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}")

      assert html_response(conn, 200) =~ "##{image.id} - safe - Derpibooru"
    end

    test "renders an embedded thumbnail through the image target", %{conn: conn} do
      target = image_fixture()
      image = image_fixture(description: ">>#{target.id}t")

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ ~s(data-image-id="#{target.id}")
    end

    test "renders description, source, and tag editing for an image owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      image =
        image_fixture(
          user_id: user.id,
          description: "Owner description",
          sources: ["https://example.com/source"]
        )

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ ~s(id="edit-description")
      assert response =~ ~s(id="edit-source")
      assert response =~ ~s(id="edit-tags")
      assert response =~ "Save sources"
      assert response =~ "Save tags"
    end

    test "an Image assistant role map enables moderation and metadata controls", %{conn: conn} do
      image =
        image_fixture(
          approved: false,
          tag_editing_allowed: false,
          description_editing_allowed: false,
          sources: ["https://example.com/source"],
          ip: %Postgrex.INET{address: {192, 0, 2, 50}, netmask: 32},
          fingerprint: "image-assistant-fingerprint"
        )

      plain_assistant = Philomena.UsersFixtures.assistant_user_fixture()

      plain_response =
        html_response(get(log_in_user(conn, plain_assistant), ~p"/images/#{image}"), 200)

      refute plain_response =~ "Manage"
      refute plain_response =~ ~p"/images/#{image}/approve"
      refute plain_response =~ "Save sources"
      refute plain_response =~ "Save tags"
      refute plain_response =~ ~s(id="edit-description")
      refute plain_response =~ "192.0.2.50"
      refute plain_response =~ "image-assistant-fingerprint"

      role_response =
        html_response(
          get(log_in_user(conn, assistant_with_image_role()), ~p"/images/#{image}"),
          200
        )

      assert role_response =~ "Manage"
      assert role_response =~ "Replace"
      assert role_response =~ "Approve image"
      assert role_response =~ "Wipe"
      assert role_response =~ ~s(id="edit-description")
      assert role_response =~ "Save sources"
      assert role_response =~ "Save tags"
      refute role_response =~ "192.0.2.50"
      refute role_response =~ "image-assistant-fingerprint"
    end

    test "does not render mutation controls for a banned viewer", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})
      image = image_fixture(faves_count: 7)

      conn = get(conn, ~p"/images/#{image}")
      response = html_response(conn, 200)

      refute response =~ ~s(id="edit-description")
      refute response =~ ~s(id="edit-source")
      refute response =~ ~s(id="edit-tags")
      refute response =~ "interaction--fave"
      refute response =~ "interaction--upvote"
      refute response =~ "interaction--downvote"
      assert response =~ ~r/class="favorites"[^>]*>7</
      assert response =~ "Unsubscribe"
    end

    test "shows anonymous visitors the counts, login prompts, and gallery links", %{conn: conn} do
      image = image_fixture(faves_count: 7, upvotes_count: 5, downvotes_count: 2, score: 3)

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ ~r/class="favorites"[^>]*>7</
      assert response =~ ~r/class="upvotes"[^>]*>5</
      assert response =~ ~r/class="downvotes"[^>]*>2</
      assert response =~ ~r/class="score[^"]*"[^>]*>3</
      assert response =~ "interaction--fave"
      assert response =~ ~s(href="/sessions/new"><i class="fa fa-bell">)
      assert response =~ "Featured in"
      assert response =~ "Sign in to create a gallery"
    end

    test "renders every control for a moderator whose first request has no fingerprint",
         %{conn: conn} do
      image = image_fixture()
      conn = log_in_user(without_fingerprint(conn), moderator_user_fixture())

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ "interaction--fave"
      assert response =~ ~s(id="edit-tags")
      assert response =~ ~s(id="uploader-form")
      assert response =~ ~s(action="/images/#{image.id}/comments")
      assert response =~ "Deletion reason (cannot be empty)"
      assert response =~ "Clear hash"
    end

    test "renders the page without moderation forms for a banned admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_admin(%{conn: conn})
      image = image_fixture()

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ "Manage"
      refute response =~ "Deletion reason (cannot be empty)"
      refute response =~ ~s(id="uploader-form")
    end

    test "renders the deleted page for an anonymous viewer", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)

      conn = get(conn, ~p"/images/#{image}")

      response = html_response(conn, 200)
      assert response =~ "This image has been deleted"
      refute response =~ "Done by:"
    end

    test "renders the deleted page for a regular viewer", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(hidden_from_users: true)

      conn = get(conn, ~p"/images/#{image}")

      response = html_response(conn, 200)
      assert response =~ "This image has been deleted"
      refute response =~ "Done by:"
    end

    test "renders the deleted page for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true)

      conn = get(conn, ~p"/images/#{image}")

      response = html_response(conn, 200)
      assert response =~ "This image has been deleted"
      assert response =~ "Done by:"
      assert response =~ ~s(id="image_options_area")
      assert response =~ "data-uris="
      refute response =~ "Destroy image"
    end

    test "an Image-admin role map moderator gets the destroy affordance", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      conn = log_in_role_moderator(conn, "Image")

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      assert response =~ "Done by:"
      assert response =~ "Destroy image"
      assert response =~ ~p"/images/#{image}/destroy"
    end

    test "regular viewers do not receive hidden image media or moderation tools", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(hidden_from_users: true)

      response = html_response(get(conn, ~p"/images/#{image}"), 200)

      refute response =~ "Done by:"
      refute response =~ ~s(id="image_options_area")
      refute response =~ "data-uris="
    end

    test "redirects a merged duplicate to its target", %{conn: conn} do
      target = image_fixture()
      duplicate = image_fixture(hidden_from_users: true, duplicate_id: target.id)

      conn = get(conn, ~p"/images/#{duplicate}")

      assert redirected_to(conn) == ~p"/images/#{target}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "has been marked a duplicate of the image below"
    end

    test "redirects to / for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    # NOTE: load_image now parses the id first, so a non-integer id redirects
    # with the not-found flash rather than raising a cast error.
    test "redirects to / with the not-found flash for a non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/images/not-a-number")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders an image via the /:id shorthand route", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, "/#{image.id}")

      assert html_response(conn, 200) =~ "##{image.id} - safe - Derpibooru"
    end
  end

  describe "GET /images/new" do
    test "renders the upload form for anonymous users", %{conn: conn} do
      conn = get(conn, ~p"/images/new")

      assert html_response(conn, 200) =~ "New Image - Derpibooru"
    end

    test "renders the upload form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/images/new")

      assert html_response(conn, 200) =~ "New Image - Derpibooru"
    end

    test "renders the upload form on a first request with no fingerprint", %{conn: conn} do
      conn = get(without_fingerprint(conn), ~p"/images/new")

      assert html_response(conn, 200) =~ "New Image - Derpibooru"
    end

    test "redirects banned users back", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/images/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned."
    end
  end

  describe "POST /images" do
    test "creates an image from a logged-in upload", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "safe, solo, pony",
            "description" => "An uploaded image"
          }
        })

      image = Repo.get_by!(Image, description: "An uploaded image")
      assert image.user_id == user.id
      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Image created successfully."

      await_async_upload()
    end

    test "creates an image from an anonymous upload", %{conn: conn} do
      conn =
        conn
        |> put_unique_ip()
        |> post(~p"/images", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "safe, solo, pony",
            "description" => "An anonymously uploaded image"
          }
        })

      image = Repo.get_by!(Image, description: "An anonymously uploaded image")
      assert image.user_id == nil
      assert redirected_to(conn) == ~p"/images/#{image}"

      await_async_upload()
    end

    test "re-renders the upload form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "solo"
          }
        })

      # NOTE: the failure branch re-renders new.html without the :title
      # assign, so pin page content rather than the title.
      response = html_response(conn, 200)
      assert response =~ "Upload a file from your computer"
      assert Repo.aggregate(Image, :count) == 0
    end

    test "re-renders the upload form without a file", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{"tag_input" => "safe, solo, pony"}
        })

      assert html_response(conn, 200) =~ "Upload a file from your computer"
      assert Repo.aggregate(Image, :count) == 0
    end

    test "redirects banned users back", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{"image" => png_upload(), "tag_input" => "safe, solo, pony"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned."
      assert Repo.aggregate(Image, :count) == 0
    end
  end

  defp hours_ago(hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 3600, :second)
    |> DateTime.truncate(:second)
  end
end
