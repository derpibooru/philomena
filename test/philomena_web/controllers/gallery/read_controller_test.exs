defmodule PhilomenaWeb.Gallery.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.GalleriesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Galleries
  alias Philomena.Notifications
  alias Philomena.Notifications.GalleryImageNotification
  alias Philomena.Repo

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/galleries/1/read"

  defp read_target(user) do
    gallery = gallery_fixture(confirmed_user_fixture())

    %{
      path: ~p"/galleries/#{gallery}/read",
      arrange!: fn ->
        {:ok, _} = Galleries.create_subscription(gallery, user)
        {:ok, 1} = Notifications.broadcast_gallery_image(gallery)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in GalleryImageNotification,
            where: n.gallery_id == ^gallery.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for an unknown gallery redirects with the not-found flash", %{conn: conn} do
    # NOTE: the context authorizes the loaded record before checking existence;
    # id 999999999 loads nil, authorization passes on the nil load, so :create
    # returns not_found and redirects instead of passing nil into
    # clear_gallery_notification/2.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/galleries/999999999/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
