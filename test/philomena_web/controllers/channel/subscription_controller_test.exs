defmodule PhilomenaWeb.Channel.SubscriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ChannelsFixtures

  alias Philomena.Channels
  alias Philomena.Repo

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/channels/1/subscription"

  defp subscription_target(user) do
    channel = channel_fixture()

    %{
      path: ~p"/channels/#{channel}/subscription",
      subscribe!: fn -> {:ok, _} = Channels.create_subscription(channel, user) end,
      subscribed?: fn ->
        Repo.exists?(
          from s in Channels.Subscription,
            where: s.channel_id == ^channel.id and s.user_id == ^user.id
        )
      end
    }
  end

  subscription_toggle_tests()

  test "POST for an unknown channel redirects to / with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/channels/999999999/subscription")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end

  test "a non-integer channel id redirects to / with the not-found flash", %{conn: conn} do
    # the central IntegerId guard short-circuits a non-integer id to
    # NotFoundPlug before authorization runs
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/channels/not-a-number/subscription")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end
end
