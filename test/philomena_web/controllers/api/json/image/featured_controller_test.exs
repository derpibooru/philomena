defmodule PhilomenaWeb.Api.Json.Image.FeaturedControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.Repo

  defp feature!(user, image) do
    %ImageFeature{user_id: user.id, image_id: image.id}
    |> ImageFeature.changeset(%{})
    |> Repo.insert!()
  end

  describe "GET /api/v1/json/images/featured" do
    test "shows the most recently featured image", %{conn: conn} do
      admin = admin_user_fixture()
      old_image = image_fixture()
      new_image = image_fixture()

      feature!(admin, old_image)

      # Backdate the first feature so the ordering is unambiguous.
      Repo.update_all(
        where(ImageFeature, image_id: ^old_image.id),
        set: [created_at: DateTime.add(DateTime.utc_now(:second), -3600)]
      )

      feature!(admin, new_image)

      conn = get(conn, ~p"/api/v1/json/images/featured")

      assert %{"image" => %{"id" => id}, "interactions" => []} = json_response(conn, 200)
      assert id == new_image.id
    end

    test "skips a hidden featured image", %{conn: conn} do
      admin = admin_user_fixture()
      visible = image_fixture()
      hidden = image_fixture(hidden_from_users: true)

      feature!(admin, visible)

      Repo.update_all(
        where(ImageFeature, image_id: ^visible.id),
        set: [created_at: DateTime.add(DateTime.utc_now(:second), -3600)]
      )

      feature!(admin, hidden)

      conn = get(conn, ~p"/api/v1/json/images/featured")

      # NOTE: a hidden latest feature does not 404; the query joins features
      # to visible images, so the newest visible feature wins.
      assert %{"image" => %{"id" => id}} = json_response(conn, 200)
      assert id == visible.id
    end

    test "returns 404 when no image has ever been featured", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/images/featured")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
