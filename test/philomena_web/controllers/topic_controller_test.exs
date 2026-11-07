defmodule PhilomenaWeb.TopicControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Topics.Topic
  alias Philomena.Repo
  alias Philomena.Roles.Role

  defp assistant_with_topic_role do
    assistant = assistant_user_fixture()
    role = Repo.insert!(%Role{name: "moderator", resource_type: "Topic"})
    Repo.insert_all("users_roles", [%{user_id: assistant.id, role_id: role.id}])
    assistant
  end

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  describe "GET /forums/:forum_id/topics/:id" do
    test "renders a topic for anonymous users", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}")
      response = html_response(conn, 200)

      assert response =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
      assert response =~ "Test topic body"
    end

    test "renders a topic for logged-in users", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}")

      assert html_response(conn, 200) =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
    end

    test "renders poll administration tabs only to topic moderators", %{
      conn: conn,
      forum: forum
    } do
      {poll_topic, _poll} = topic_with_poll_fixture(forum)

      anonymous_response =
        html_response(get(conn, ~p"/forums/#{forum}/topics/#{poll_topic}"), 200)

      assert anonymous_response =~ "Voting"
      assert anonymous_response =~ "Option A"
      refute anonymous_response =~ "Voters"
      refute anonymous_response =~ "Administrate"
      refute anonymous_response =~ ~p"/forums/#{forum}/topics/#{poll_topic}/poll/edit"

      moderator_response =
        html_response(
          get(
            log_in_user(conn, moderator_user_fixture()),
            ~p"/forums/#{forum}/topics/#{poll_topic}"
          ),
          200
        )

      assert moderator_response =~ "Voters"
      assert moderator_response =~ "Administrate"
      assert moderator_response =~ ~p"/forums/#{forum}/topics/#{poll_topic}/poll/votes"
      assert moderator_response =~ ~p"/forums/#{forum}/topics/#{poll_topic}/poll/edit"
    end

    test "renders locked-topic disclosure and moderation tools by ability", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      locking_moderator = moderator_user_fixture(%{name: "Locking Topic Moderator"})

      locked_topic =
        topic
        |> Ecto.Changeset.change(
          locked_at: DateTime.utc_now(:second),
          lock_reason: "No further replies",
          locked_by_id: locking_moderator.id
        )
        |> Repo.update!()

      anonymous_response =
        html_response(get(conn, ~p"/forums/#{forum}/topics/#{locked_topic}"), 200)

      assert anonymous_response =~ "This topic has been locked to new posts from non-moderators."
      assert anonymous_response =~ "No further replies"
      refute anonymous_response =~ "Locking Topic Moderator"
      refute anonymous_response =~ ~s(name="post[body]")
      refute anonymous_response =~ "Manage Topic"

      moderator_response =
        html_response(
          get(
            log_in_user(conn, moderator_user_fixture()),
            ~p"/forums/#{forum}/topics/#{locked_topic}"
          ),
          200
        )

      assert moderator_response =~ "Locking Topic Moderator"
      assert moderator_response =~ "Manage Topic"
      assert moderator_response =~ "Unlock"
      assert moderator_response =~ ~s(name="post[body]")
    end

    test "renders hidden topic contents only to viewers with topic access", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      deleter = moderator_user_fixture(%{name: "Topic Deleter"})

      hidden_topic =
        topic
        |> Ecto.Changeset.change(
          hidden_from_users: true,
          deletion_reason: "Hidden topic reason",
          deleted_by_id: deleter.id
        )
        |> Repo.update!()

      anonymous_conn = get(conn, ~p"/forums/#{forum}/topics/#{hidden_topic}")
      assert redirected_to(anonymous_conn) == "/"

      regular_conn =
        get(
          log_in_user(conn, confirmed_user_fixture()),
          ~p"/forums/#{forum}/topics/#{hidden_topic}"
        )

      assert redirected_to(regular_conn) == "/"

      moderator_response =
        html_response(
          get(
            log_in_user(conn, moderator_user_fixture()),
            ~p"/forums/#{forum}/topics/#{hidden_topic}"
          ),
          200
        )

      assert moderator_response =~ "Hidden topic reason"
      assert moderator_response =~ "Topic Deleter"
      assert moderator_response =~ "Restore"
      assert moderator_response =~ "Test topic body"
      assert moderator_response =~ "Manage Topic"
    end

    test "reveals anonymous topic authors only to moderators", %{conn: conn, forum: forum} do
      author = confirmed_user_fixture(%{name: "Anonymous Topic Author"})

      anonymous_topic =
        topic_fixture(forum, author, %{
          "title" => "Anonymous topic attribution",
          "anonymous" => "true"
        })

      anonymous_response =
        html_response(get(conn, ~p"/forums/#{forum}/topics/#{anonymous_topic}"), 200)

      refute anonymous_response =~ "Anonymous Topic Author"
      assert anonymous_response =~ ~r/Background Pony #[0-9A-F]{4}/

      moderator_response =
        html_response(
          get(
            log_in_user(conn, moderator_user_fixture()),
            ~p"/forums/#{forum}/topics/#{anonymous_topic}"
          ),
          200
        )

      assert moderator_response =~ "Anonymous Topic Author"
      assert moderator_response =~ "hidden"

      staff_tools_hidden_response =
        html_response(
          get(
            log_in_user(
              put_req_cookie(conn, "hide_staff_tools", "true"),
              moderator_user_fixture()
            ),
            ~p"/forums/#{forum}/topics/#{anonymous_topic}"
          ),
          200
        )

      refute staff_tools_hidden_response =~ "Anonymous Topic Author"
      assert staff_tools_hidden_response =~ ~r/Background Pony #[0-9A-F]{4}/
    end

    test "renders pending-post approval controls for moderators and Topic assistants",
         %{conn: conn, forum: forum, topic: topic} do
      author = confirmed_user_fixture()

      pending =
        post_fixture(topic, author, %{"body" => "Pending post body"})
        |> Ecto.Changeset.change(approved: false)
        |> Repo.update!()

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/forums/#{forum}/topics/#{topic}"),
          200
        )

      assert moderator_response =~ "pending approval from a staff member"
      assert moderator_response =~ pending.body
      assert moderator_response =~ ~p"/forums/#{forum}/topics/#{topic}/posts/#{pending}/approve"
      assert moderator_response =~ "Reject"

      plain_assistant_response =
        html_response(
          get(log_in_user(conn, assistant_user_fixture()), ~p"/forums/#{forum}/topics/#{topic}"),
          200
        )

      refute plain_assistant_response =~
               ~p"/forums/#{forum}/topics/#{topic}/posts/#{pending}/approve"

      refute plain_assistant_response =~ pending.body

      topic_assistant_response =
        html_response(
          get(
            log_in_user(conn, assistant_with_topic_role()),
            ~p"/forums/#{forum}/topics/#{topic}"
          ),
          200
        )

      assert topic_assistant_response =~
               ~p"/forums/#{forum}/topics/#{topic}/posts/#{pending}/approve"

      assert topic_assistant_response =~
               ~p"/forums/#{forum}/topics/#{topic}/posts/#{pending}/edit"
    end

    test "renders post history and edit affordances according to the viewer", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      author = confirmed_user_fixture()

      edited =
        post_fixture(topic, author, %{"body" => "Edited post body"})
        |> Ecto.Changeset.change(
          edited_at: DateTime.utc_now(:second),
          edit_reason: "Fixed a typo"
        )
        |> Repo.update!()

      author_response =
        html_response(
          get(log_in_user(conn, author), ~p"/forums/#{forum}/topics/#{topic}"),
          200
        )

      assert author_response =~ "Edited"
      assert author_response =~ ~p"/forums/#{forum}/topics/#{topic}/posts/#{edited}/history"
      assert author_response =~ ~p"/forums/#{forum}/topics/#{topic}/posts/#{edited}/edit"

      other_response =
        html_response(
          get(log_in_user(conn, confirmed_user_fixture()), ~p"/forums/#{forum}/topics/#{topic}"),
          200
        )

      assert other_response =~ ~p"/forums/#{forum}/topics/#{topic}/posts/#{edited}/history"
      refute other_response =~ ~p"/forums/#{forum}/topics/#{topic}/posts/#{edited}/edit"
    end

    test "renders deleted post disclosure and moderation controls for staff", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      deleter = moderator_user_fixture(%{name: "Post Moderator"})

      hidden =
        post_fixture(topic, confirmed_user_fixture(), %{"body" => "Hidden post body"})
        |> Ecto.Changeset.change(
          hidden_from_users: true,
          deletion_reason: "Rule violation",
          deleted_by_id: deleter.id,
          ip: %Postgrex.INET{address: {192, 0, 2, 70}, netmask: 32},
          fingerprint: "post-staff-fingerprint"
        )
        |> Repo.update!()

      response =
        html_response(get(log_in_user(conn, deleter), ~p"/forums/#{forum}/topics/#{topic}"), 200)

      assert response =~ "Rule violation"
      assert response =~ "Post Moderator"
      assert response =~ "Hidden post body"
      assert response =~ "Restore"
      assert response =~ "Delete Contents"
      assert response =~ "192.0.2.70"
      assert response =~ "post-staff-fingerprint"

      destroyed =
        hidden
        |> Ecto.Changeset.change(destroyed_content: true, body: "")
        |> Repo.update!()

      destroyed_response =
        html_response(get(log_in_user(conn, deleter), ~p"/forums/#{forum}/topics/#{topic}"), 200)

      assert destroyed_response =~ "This post's contents have been destroyed."
      refute destroyed_response =~ "Hidden post body"
      refute destroyed_response =~ "Delete Contents"
      _ = destroyed
    end

    test "a Topic assistant can moderate hidden posts without destroy or identity controls", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      deleter = moderator_user_fixture(%{name: "Hidden Post Moderator"})

      post =
        post_fixture(topic, confirmed_user_fixture(), %{"body" => "Assistant hidden body"})
        |> Ecto.Changeset.change(
          hidden_from_users: true,
          deletion_reason: "Assistant rule violation",
          deleted_by_id: deleter.id,
          ip: %Postgrex.INET{address: {192, 0, 2, 71}, netmask: 32},
          fingerprint: "assistant-post-fingerprint"
        )
        |> Repo.update!()

      response =
        html_response(
          get(
            log_in_user(conn, assistant_with_topic_role()),
            ~p"/forums/#{forum}/topics/#{topic}"
          ),
          200
        )

      assert response =~ "Assistant rule violation"
      assert response =~ "Hidden Post Moderator"
      assert response =~ "Assistant hidden body"
      assert response =~ "Restore"
      refute response =~ "Delete Contents"
      refute response =~ "192.0.2.71"
      refute response =~ "assistant-post-fingerprint"
      _ = post
    end

    test "redirects to / for an unknown topic", %{conn: conn, forum: forum} do
      conn = get(conn, ~p"/forums/#{forum}/topics/nonexistent-topic")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for an unknown forum", %{conn: conn, topic: topic} do
      conn = get(conn, ~p"/forums/nonexistent-forum/topics/#{topic}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for a hidden topic viewed anonymously", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      topic
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end

  describe "GET /:forum_id/:id (shorthand routes)" do
    test "renders a topic", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, "/#{forum.short_name}/#{topic.slug}")

      assert html_response(conn, 200) =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
    end

    test "renders a topic page", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, "/#{forum.short_name}/#{topic.slug}/1")

      assert html_response(conn, 200) =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
    end

    test "renders the page containing a given post", %{conn: conn, forum: forum, topic: topic} do
      post = post_fixture(topic, nil, %{"body" => "Test navigated post body"})

      conn = get(conn, "/#{forum.short_name}/#{topic.slug}/post/#{post.id}")

      assert html_response(conn, 200) =~ "Test navigated post body"
    end
  end

  describe "GET /forums/:forum_id/topics/new" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum} do
      conn = get(conn, ~p"/forums/#{forum}/topics/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the form for logged-in users", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/forums/#{forum}/topics/new"), 200)

      assert response =~ "New Topic - Derpibooru"
    end

    test "redirects banned users with the ban flash", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "redirects to / for an unknown forum", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/nonexistent-forum/topics/new")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "renders the form without a fingerprint", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/forums/#{forum}/topics/new")

      assert html_response(conn, 200) =~ "New Topic - Derpibooru"
    end
  end

  describe "POST /forums/:forum_id/topics" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum} do
      conn = post(conn, ~p"/forums/#{forum}/topics", %{})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "creates the topic and first post and redirects to it", %{conn: conn, forum: forum} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics", %{
          "topic" => %{
            "title" => "A brand new topic",
            "anonymous" => "false",
            "posts" => %{"0" => %{"body" => "First post body"}}
          }
        })

      topic =
        Repo.one!(from t in Topic, where: t.forum_id == ^forum.id and t.user_id == ^user.id)
        |> Repo.preload(:posts)

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully posted topic."
      assert topic.title == "A brand new topic"
      assert [%{body: "First post body"}] = topic.posts
    end

    test "re-renders the form when the title is too short", %{conn: conn, forum: forum} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics", %{
          "topic" => %{
            "title" => "abc",
            "anonymous" => "false",
            "posts" => %{"0" => %{"body" => "First post body"}}
          }
        })

      # the re-render is missing the :title assign (same shape as conversation
      # create failure); pin the form's error box instead
      response = html_response(conn, 200)
      assert response =~ "Oops, something went wrong! Please check the errors below."
      assert response =~ "Create a Topic"
      assert Repo.aggregate(from(t in Topic, where: t.user_id == ^user.id), :count) == 0
    end

    test "redirects banned users with the ban flash", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash",
         %{conn: conn, forum: forum} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/forums/#{forum}/topics", %{
          "topic" => %{
            "title" => "A brand new topic",
            "posts" => %{"0" => %{"body" => "First post body"}}
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.exists?(from t in Topic, where: t.user_id == ^user.id)
    end
  end

  describe "PATCH /forums/:forum_id/topics/:id" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "redirects regular users (even the topic author) with the authorization flash",
         %{conn: conn, forum: forum} do
      # :edit on a Topic is a moderator-only ability; there is no owner rule
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      topic = topic_fixture(forum, user)

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{
          "topic" => %{"title" => "Renamed by author"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).title == topic.title
    end

    test "updates the title as a moderator without changing the slug",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{
          "topic" => %{"title" => "Renamed by moderator"}
        })

      # the redirect still uses the original slug: title_changeset does not re-slug
      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated topic."

      reloaded = Repo.reload!(topic)
      assert reloaded.title == "Renamed by moderator"
      assert reloaded.slug == topic.slug
    end

    test "PUT also updates the title", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/forums/#{forum}/topics/#{topic}", %{
          "topic" => %{"title" => "Renamed via PUT"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Repo.reload!(topic).title == "Renamed via PUT"
    end

    test "redirects back to the topic with the error flash when the title is too short",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{"topic" => %{"title" => "abc"}})

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "There was an error with your submission. Please try again."

      assert Repo.reload!(topic).title == topic.title
    end

    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/nonexistent-topic", %{
          "topic" => %{"title" => "Renamed"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
