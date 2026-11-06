defmodule PhilomenaWeb.Image.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Notifications
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification
  alias Philomena.Repo

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/images/1/read"

  defp read_target(user) do
    image = image_fixture()

    %{
      path: ~p"/images/#{image}/read",
      arrange!: fn ->
        {:ok, _} = Images.create_subscription(image, user)
        author = confirmed_user_fixture()
        comment = comment_fixture(image, author)
        {:ok, 1} = Notifications.broadcast_image_comment(author, image, comment)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in ImageCommentNotification,
            where: n.image_id == ^image.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for a hidden image clears comment and merge notifications only for the current user",
       %{
         conn: conn
       } do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    source = image_fixture()
    other_user = confirmed_user_fixture()
    author = confirmed_user_fixture()
    comment = comment_fixture(image, author)

    for subscriber <- [user, other_user] do
      {:ok, _} = Images.create_subscription(image, subscriber)
    end

    {:ok, 2} = Notifications.broadcast_image_comment(author, image, comment)
    {:ok, 3} = Notifications.broadcast_image_merge(image, source)
    image |> Ecto.Changeset.change(hidden_from_users: true) |> Repo.update!()

    conn = post(conn, ~p"/images/#{image}/read")

    assert response(conn, 200) == ""

    for schema <- [ImageCommentNotification, ImageMergeNotification] do
      refute Repo.exists?(from n in schema, where: n.user_id == ^user.id)
      assert Repo.exists?(from n in schema, where: n.user_id == ^other_user.id)
    end
  end

  test "POST for an unknown image redirects with the not-found flash", %{conn: conn} do
    # NOTE: the context authorizes the loaded record on :create; id 999999999
    # Missing image locators resolve to not-found before authorization.
    # and redirects instead of passing nil into clear_image_notification/2.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/images/999999999/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
