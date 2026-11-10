defmodule PhilomenaWeb.Image.SubscriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ImagesFixtures

  alias Philomena.Images
  alias Philomena.Repo

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/images/1/subscription"

  defp subscription_target(user) do
    image = image_fixture()

    %{
      path: ~p"/images/#{image}/subscription",
      subscribe!: fn -> {:ok, _} = Images.create_subscription(image, user) end,
      subscribed?: fn ->
        Repo.exists?(
          from s in Images.Subscription,
            where: s.image_id == ^image.id and s.user_id == ^user.id
        )
      end
    }
  end

  subscription_toggle_tests()

  test "POST for an unknown image redirects to / with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/images/999999999/subscription")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "banned users can subscribe", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_banned_user(%{conn: conn})
    target = subscription_target(user)

    conn = post(conn, target.path)

    assert response(conn, 200) =~ "js-subscription-target"
    assert target.subscribed?.()
  end
end
