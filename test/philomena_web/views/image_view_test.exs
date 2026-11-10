defmodule PhilomenaWeb.ImageViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias PhilomenaWeb.ImageView

  describe "hidden-image disclosure" do
    setup _context do
      image =
        image_fixture(
          hidden_from_users: true,
          hidden_image_key: "image-secret",
          image_width: 1000,
          image_height: 1000
        )

      {:ok, image: Repo.preload(image, tags: :aliases)}
    end

    test "render_intent omits the hidden thumbnail path for regular viewers", %{
      conn: conn,
      image: image
    } do
      {:image, url, _alt} = ImageView.render_intent(viewer_conn(conn, nil), image, :thumb)

      assert url =~ "/#{image.id}/thumb.png"
      refute url =~ image.hidden_image_key
    end

    test "render_intent includes the hidden thumbnail path for moderators", %{
      conn: conn,
      image: image
    } do
      moderator_conn = viewer_conn(conn, moderator_user_fixture())
      {:image, url, _alt} = ImageView.render_intent(moderator_conn, image, :thumb)

      assert url =~ "#{image.id}-#{image.hidden_image_key}/thumb.png"
    end

    test "image_container_data redacts hidden URIs from regular viewers", %{
      conn: conn,
      image: image
    } do
      data = ImageView.image_container_data(viewer_conn(conn, nil), image, :full)

      refute data[:uris] =~ image.hidden_image_key
    end

    test "image_container_data includes hidden URIs for moderators", %{
      conn: conn,
      image: image
    } do
      data =
        ImageView.image_container_data(viewer_conn(conn, moderator_user_fixture()), image, :full)

      assert data[:uris] =~ image.hidden_image_key
    end
  end

  describe "hides_images?/1" do
    test "is false for anonymous and regular viewers", %{conn: conn} do
      assert ImageView.hides_images?(viewer_conn(conn, nil)) == false
      assert ImageView.hides_images?(viewer_conn(conn, confirmed_user_fixture())) == false
    end

    test "is true for moderators", %{conn: conn} do
      assert ImageView.hides_images?(viewer_conn(conn, moderator_user_fixture())) == true
    end
  end
end
