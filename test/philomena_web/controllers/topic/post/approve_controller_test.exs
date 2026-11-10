defmodule PhilomenaWeb.Topic.Post.ApproveControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures
  import Philomena.RulesFixtures

  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  defp approval_rule! do
    rule_fixture()
    |> Ecto.Changeset.change(name: "Approval")
    |> Repo.update!()
  end

  # A post authored by a fresh (untrusted) user containing an external link is
  # not auto-approved on creation (see Philomena.Schema.Approval).
  defp unapproved_post(topic) do
    approval_rule!()

    post =
      post_fixture(topic, confirmed_user_fixture(), %{
        "body" => "check this out https://spam.example/"
      })

    refute post.approved
    post
  end

  defp post_anchor(forum, topic, post) do
    ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"
  end

  describe "POST /forums/:forum_id/topics/:topic_id/posts/:post_id/approve" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic} do
      post = unapproved_post(topic)

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(post).approved
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      post = unapproved_post(topic)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(post).approved
    end

    test "as a moderator approves the post",
         %{conn: conn, forum: forum, topic: topic} do
      post = unapproved_post(topic)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert redirected_to(conn) == post_anchor(forum, topic, post)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully approved."
      assert Repo.reload!(post).approved
    end

    test "approving an already-approved post still succeeds",
         %{conn: conn, forum: forum, topic: topic} do
      post = post_fixture(topic)
      assert post.approved
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post has already been approved."
      assert Repo.reload!(post).approved
    end

    # Failure path: the only reachable failure surface is an unknown post -
    # the context authorizes the nil load, which no moderator rule matches, so
    # it returns unauthorized and redirects with the authorization flash.
    test "for an unknown post_id redirects with the not-found flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer post_id short-circuits to NotFoundPlug via the central
    # IntegerId guard, redirecting with the not-found flash.
    test "for a non-integer post_id redirects with the not-found flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/not-a-number/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
