defmodule PhilomenaWeb.Topic.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Posts.Post
  alias Philomena.Topics
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  describe "POST /forums/:forum_id/topics/:topic_id/posts" do
    test "creates a post anonymously", %{conn: conn, forum: forum, topic: topic} do
      conn =
        conn
        |> put_unique_ip()
        |> post(~p"/forums/#{forum}/topics/#{topic}/posts", %{
          "post" => %{"body" => "An anonymous reply"}
        })

      post =
        Repo.one!(from p in Post, where: p.topic_id == ^topic.id and p.topic_position > 0)

      assert redirected_to(conn) ==
               ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post created successfully."
      assert post.body == "An anonymous reply"
      assert post.user_id == nil
    end

    test "creates a post as a logged-in user", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts", %{
          "post" => %{"body" => "A logged-in reply"}
        })

      post =
        Repo.one!(from p in Post, where: p.topic_id == ^topic.id and p.topic_position > 0)

      assert redirected_to(conn) ==
               ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"

      assert post.user_id == user.id
    end

    test "redirects back to the topic with the error flash when the body is blank",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts", %{"post" => %{"body" => ""}})

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "There was an error creating the post"

      assert Repo.aggregate(from(p in Post, where: p.topic_id == ^topic.id), :count) == 1
    end

    test "redirects with the authorization flash when the topic is locked",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      moderator = Philomena.UsersFixtures.moderator_user_fixture()

      {:ok, {_forum, _topic}} =
        Topics.create_topic_lock(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"lock_reason" => "Test lock"}
        )

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts", %{
          "post" => %{"body" => "Reply to a locked topic"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/posts", %{
          "post" => %{"body" => "Reply to nothing"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects banned users with the ban flash", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "GET /forums/:forum_id/topics/:topic_id/posts/:id/edit" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      post = post_fixture(topic)

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/edit")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the form for the post's author", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, user)

      response =
        html_response(get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/edit"), 200)

      assert response =~ "Editing Post - Derpibooru"
    end

    test "redirects other users with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, Philomena.UsersFixtures.confirmed_user_fixture())

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a moderator", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      post = post_fixture(topic, Philomena.UsersFixtures.confirmed_user_fixture())

      response =
        html_response(get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/edit"), 200)

      assert response =~ "Editing Post - Derpibooru"
    end

    test "redirects to / with the not-found flash for an unknown post",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the form for the author without a fingerprint",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, user)

      conn =
        get(without_fingerprint(conn), ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/edit")

      assert html_response(conn, 200) =~ "Editing Post - Derpibooru"
    end
  end

  describe "PATCH /forums/:forum_id/topics/:topic_id/posts/:id" do
    test "updates the post body as the author and creates a version",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, user, %{"body" => "Original reply body"})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}", %{
          "post" => %{"body" => "Original reply body plus an edit", "edit_reason" => "typo"}
        })

      assert redirected_to(conn) ==
               ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully edited."

      reloaded = Repo.reload!(post)
      assert reloaded.body == "Original reply body plus an edit"
      assert reloaded.edit_reason == "typo"

      assert Repo.exists?(from v in Philomena.Posts.PostVersion, where: v.post_id == ^post.id)
    end

    test "PUT also updates the post", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, user)

      conn =
        put(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}", %{
          "post" => %{"body" => "Updated via PUT"}
        })

      assert redirected_to(conn) ==
               ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"

      assert Repo.reload!(post).body == "Updated via PUT"
    end

    test "re-renders the form when the body is blank", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, user, %{"body" => "Original reply body"})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}", %{
          "post" => %{"body" => ""}
        })

      response = html_response(conn, 200)
      assert response =~ "Oops, something went wrong! Please check the errors below."
      assert Repo.reload!(post).body == "Original reply body"
    end

    test "redirects other users with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, Philomena.UsersFixtures.confirmed_user_fixture())

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}", %{
          "post" => %{"body" => "Hijacked"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(post).body == post.body
    end

    test "without a fingerprint redirects to / with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      post = post_fixture(topic, user, %{"body" => "Original reply body"})

      conn =
        patch(without_fingerprint(conn), ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}", %{
          "post" => %{"body" => "Edited without a fingerprint"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(post).body == "Original reply body"
    end
  end
end
