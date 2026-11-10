defmodule PhilomenaWeb.UserAttributionViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Comments.Comment
  alias Philomena.Comments.CommentVersion
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange
  alias Philomena.Topics.Topic

  defp render_anon_user(conn, object) do
    Phoenix.View.render_to_string(
      PhilomenaWeb.UserAttributionView,
      "_anon_user.html",
      %{conn: conn, object: object}
    )
  end

  defp anonymous_objects(user) do
    image = %Image{id: 1001, user_id: user.id, user: user, anonymous: true}

    comment = %Comment{
      id: 1002,
      image_id: image.id,
      user_id: user.id,
      user: user,
      anonymous: true
    }

    post = %Post{id: 1003, topic_id: 1004, user_id: user.id, user: user, anonymous: true}
    topic = %Topic{id: 1004, user_id: user.id, user: user, anonymous: true}
    gallery = %Gallery{id: 1005, user_id: user.id, user: user, anonymous: true}

    source_change = %SourceChange{
      id: 1006,
      image_id: image.id,
      user_id: user.id,
      user: user,
      image: image
    }

    tag_change = %TagChange{
      id: 1007,
      image_id: image.id,
      user_id: user.id,
      user: user,
      image: image
    }

    comment_version = %CommentVersion{
      id: 1008,
      user: user,
      parent: comment
    }

    post_version = %PostVersion{
      id: 1009,
      user: user,
      parent: post
    }

    [
      {:image, image},
      {:comment, comment},
      {:post, post},
      {:topic, topic},
      {:gallery, gallery},
      {:source_change, source_change},
      {:tag_change, tag_change},
      {:comment_version, comment_version},
      {:post_version, post_version}
    ]
  end

  describe "anonymous attribution disclosure" do
    test "uses a pseudonym for every attribution object unless a moderator may reveal it", %{
      conn: conn
    } do
      user = confirmed_user_fixture(%{name: "Attribution Disclosure User"})
      objects = anonymous_objects(user)

      anonymous_conn =
        conn
        |> Plug.Conn.assign(:current_user, nil)
        |> Plug.Conn.fetch_cookies()

      for {label, object} <- objects do
        response = render_anon_user(anonymous_conn, object)

        refute response =~ user.name, "#{label} leaked the anonymous user's name"
        assert response =~ ~r/Background Pony #[0-9A-F]{4}/, "#{label} lacked its pseudonym"
      end

      regular_conn =
        conn
        |> Plug.Conn.assign(:current_user, confirmed_user_fixture())
        |> Plug.Conn.fetch_cookies()

      for {label, object} <- objects do
        response = render_anon_user(regular_conn, object)

        refute response =~ user.name, "#{label} revealed the name to a regular user"
        assert response =~ ~r/Background Pony #[0-9A-F]{4}/, "#{label} lacked its pseudonym"
      end

      moderator = moderator_user_fixture()

      moderator_conn =
        conn
        |> Plug.Conn.assign(:current_user, moderator)
        |> Plug.Conn.fetch_cookies()

      for {label, object} <- objects do
        response = render_anon_user(moderator_conn, object)

        assert response =~ user.name, "#{label} did not reveal the anonymous user's name"
        assert response =~ "hidden", "#{label} lacked the hidden attribution marker"
      end
    end

    test "hide_staff_tools suppresses anonymous identity reveal for every attribution object", %{
      conn: conn
    } do
      user = confirmed_user_fixture(%{name: "Hidden Staff Tools User"})
      moderator = moderator_user_fixture()

      moderator_conn =
        conn
        |> Plug.Conn.assign(:current_user, moderator)
        |> Plug.Conn.put_req_header("cookie", "hide_staff_tools=true")
        |> Plug.Conn.fetch_cookies()

      for {label, object} <- anonymous_objects(user) do
        response = render_anon_user(moderator_conn, object)

        refute response =~ user.name, "#{label} ignored hide_staff_tools"
        assert response =~ ~r/Background Pony #[0-9A-F]{4}/, "#{label} lacked its pseudonym"
      end
    end
  end
end
