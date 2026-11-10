defmodule PhilomenaWeb.Forum.SubscriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ForumsFixtures

  alias Philomena.Forums
  alias Philomena.Repo

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/forums/dummy/subscription"

  defp subscription_target(user) do
    forum = forum_fixture()

    %{
      path: ~p"/forums/#{forum}/subscription",
      subscribe!: fn -> {:ok, _} = Forums.create_subscription(forum, user) end,
      subscribed?: fn ->
        Repo.exists?(
          from s in Forums.Subscription,
            where: s.forum_id == ^forum.id and s.user_id == ^user.id
        )
      end
    }
  end

  subscription_toggle_tests()

  test "POST for an unknown forum redirects to / with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/forums/nonexistent/subscription")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "POST for a staff forum as a regular user redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture(%{access_level: "staff"})

    conn = post(conn, ~p"/forums/#{forum}/subscription")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end
end
