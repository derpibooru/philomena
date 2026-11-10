defmodule PhilomenaWeb.Image.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias Philomena.Repo
  alias Philomena.Roles.Role

  defp mark_unapproved(comment), do: Repo.update!(Ecto.Changeset.change(comment, approved: false))

  defp hidden_comment(image, body) do
    comment = comment_fixture(image, nil, %{"body" => body})
    moderator = moderator_user_fixture(%{name: "Comment Deleter"})

    {:ok, comment} =
      Comments.create_comment_hide(
        actor(moderator),
        image.id,
        comment.id,
        %{"deletion_reason" => "Comment policy violation"}
      )

    {comment, moderator}
  end

  defp assistant_with_comment_role do
    assistant = assistant_user_fixture()
    role = Repo.insert!(%Role{name: "moderator", resource_type: "Comment"})
    Repo.insert_all("users_roles", [%{user_id: assistant.id, role_id: role.id}])
    assistant
  end

  describe "GET /images/:image_id/comments" do
    test "renders the comment list without a layout", %{conn: conn} do
      image = image_fixture()
      _comment = comment_fixture(image, nil, %{"body" => "Test listed comment body"})

      conn = get(conn, ~p"/images/#{image}/comments")
      response = html_response(conn, 200)

      assert response =~ "Test listed comment body"
      refute response =~ "Derpibooru"
    end

    test "redirects to the page containing a given comment", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments?comment_id=#{comment.id}")

      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/comments")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the approval action only for a comment moderator", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "Pending body"})
      mark_unapproved(comment)

      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      response = html_response(get(conn, ~p"/images/#{image}/comments"), 200)

      assert response =~ "This comment is pending approval from a staff member."
      assert response =~ ~p"/images/#{image}/comments/#{comment}/approve"
    end

    test "does not render approval for the pending comment's author", %{conn: conn} do
      author = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, author, %{"body" => "Author pending body"})
      mark_unapproved(comment)
      conn = log_in_user(conn, author)

      response = html_response(get(conn, ~p"/images/#{image}/comments"), 200)

      assert response =~ "This comment is pending approval from a staff member."
      refute response =~ ~p"/images/#{image}/comments/#{comment}/approve"
    end

    test "renders owner edit and visible history links", %{conn: conn} do
      %{conn: conn, user: author} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, author, %{"body" => "Edited comment body"})

      comment =
        Repo.update!(
          Ecto.Changeset.change(comment,
            edited_at: DateTime.utc_now(:second),
            edit_reason: "Typo"
          )
        )

      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}"), 200)

      assert response =~ ~p"/images/#{image}/comments/#{comment}/edit"
      assert response =~ ~p"/images/#{image}/comments/#{comment}/history"
    end

    test "renders staff moderation controls and identity metadata", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Visible moderation body"})

      Repo.update!(
        Ecto.Changeset.change(comment,
          ip: %Postgrex.INET{address: {192, 0, 2, 42}, netmask: 32},
          fingerprint: "abc1234secret"
        )
      )

      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}"), 200)

      assert response =~ ~p"/images/#{image}/comments/#{comment}/hide"
      assert response =~ "Delete"
      assert response =~ "192.0.2.42"
      assert response =~ "abc1234"
    end

    test "a Comment assistant can moderate without delete or identity controls", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Assistant moderation body"})

      Repo.update!(
        Ecto.Changeset.change(comment,
          ip: %Postgrex.INET{address: {192, 0, 2, 43}, netmask: 32},
          fingerprint: "assistant-fingerprint"
        )
      )

      assistant = assistant_with_comment_role()
      conn = log_in_user(conn, assistant)

      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}"), 200)

      assert response =~ ~p"/images/#{image}/comments/#{comment}/hide"
      refute response =~ ~p"/images/#{image}/comments/#{comment}/delete"
      refute response =~ "192.0.2.43"
      refute response =~ "assista"
      refute response =~ "assistant-fingerprint"
    end

    test "discloses deleted moderator and restore/delete actions to staff", %{conn: conn} do
      image = image_fixture()
      {comment, moderator} = hidden_comment(image, "Hidden comment body")
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}"), 200)

      assert response =~ "Comment policy violation"
      assert response =~ moderator.name
      assert response =~ "Hidden comment body"
      assert response =~ "Restore"
      assert response =~ ~p"/images/#{image}/comments/#{comment}/delete"
      assert response =~ "Delete Contents"
    end

    test "renders a hidden comment as its deletion reason to an anonymous visitor", %{
      conn: conn
    } do
      image = image_fixture()
      {comment, moderator} = hidden_comment(image, "Private hidden comment body")

      for path <- [~p"/images/#{image}/comments", ~p"/images/#{image}/comments/#{comment}"] do
        response = html_response(get(conn, path), 200)

        assert response =~ "Deletion reason:"
        assert response =~ "Comment policy violation"
        refute response =~ "Private hidden comment body"
        refute response =~ moderator.name
        refute response =~ ~p"/images/#{image}/comments/#{comment}/delete"
      end

      conn = get(conn, ~p"/images/#{image}/comments?comment_id=#{comment.id}")
      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
    end

    test "renders destroyed state without the original body", %{conn: conn} do
      image = image_fixture()
      {comment, _moderator} = hidden_comment(image, "Destroyed comment body")

      {:ok, _comment} =
        Comments.create_comment_delete(
          actor(moderator_user_fixture()),
          image.id,
          comment.id
        )

      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}"), 200)

      assert response =~ "This comment's contents have been destroyed."
      refute response =~ "Destroyed comment body"
      refute response =~ "Delete Contents"
    end
  end

  describe "GET /images/:image_id/comments/:id" do
    test "renders a single comment without a layout", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test shown comment body"})

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}")
      response = html_response(conn, 200)

      assert response =~ "Test shown comment body"
      refute response =~ "Derpibooru"
    end

    test "redirects to / for a comment on a hidden image", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      comment = comment_fixture(image, moderator_user_fixture())

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for an unknown comment", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/comments/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / when the route image does not own the comment", %{conn: conn} do
      image = image_fixture()
      other_image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{other_image}/comments/#{comment}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "POST /images/:image_id/comments" do
    test "as a logged-in user creates the comment and redirects to its page", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "A brand new comment"}
        })

      comment = Repo.one!(from c in Comment, where: c.image_id == ^image.id)

      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
      assert comment.user_id == user.id
      assert comment.body == "A brand new comment"
      assert comment.approved
      assert Repo.reload!(image).comments_count == 1
    end

    test "anonymously creates the comment", %{conn: conn} do
      image = image_fixture()

      conn =
        conn
        |> put_unique_ip()
        |> post(~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "An anonymous comment"}
        })

      comment = Repo.one!(from c in Comment, where: c.image_id == ^image.id)

      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
      assert comment.user_id == nil
      assert comment.body == "An anonymous comment"
    end

    test "with an empty body redirects to the image with an error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments", %{"comment" => %{"body" => ""}})

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "There was an error posting your comment"

      assert Repo.aggregate(Comment, :count) == 0
    end

    test "on an image with commenting disabled redirects with the authorization flash",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(commenting_allowed: false)

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "Should not appear"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "as a banned user redirects with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "Should not appear"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "a forced-filter match redirects without creating a comment", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      filter = system_filter_fixture(hidden_complex_str: "id:#{image.id}")

      user
      |> Ecto.Changeset.change(forced_filter_id: filter.id)
      |> Repo.update!()

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "Should not appear"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You have been blocked from performing this action on this image."

      assert Repo.aggregate(Comment, :count) == 0
    end
  end

  describe "GET /images/:image_id/comments/:id/edit" do
    test "anonymous request redirects to the login page", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/edit")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "as the comment author renders the edit form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Editable comment body"})

      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}/edit"), 200)

      assert response =~ "Editing Comment - Derpibooru"
      assert response =~ "Editable comment body"
    end

    test "as another user redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture())

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "the author cannot edit through a different route image", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      other_image = image_fixture()
      comment = comment_fixture(image, user)

      conn = get(conn, ~p"/images/#{other_image}/comments/#{comment}/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the edit form for the author without a fingerprint", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user)

      conn = get(without_fingerprint(conn), ~p"/images/#{image}/comments/#{comment}/edit")

      assert html_response(conn, 200) =~ "Editing Comment - Derpibooru"
    end
  end

  describe "PATCH /images/:image_id/comments/:id" do
    test "as the comment author updates the body and redirects to the image", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        patch(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Original comment body plus an edit"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment updated successfully."
      assert Repo.reload!(comment).body == "Original comment body plus an edit"
    end

    test "with an empty body re-renders the edit form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        patch(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => ""}
        })

      # the error branch re-renders edit.html without the :title assign,
      # so the page title is bare "Derpibooru"; pin the form's error box
      assert html_response(conn, 200) =~
               "Oops, something went wrong! Please check the errors below."

      assert Repo.reload!(comment).body == "Original comment body"
    end

    test "as another user redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "Untouchable"})

      conn =
        patch(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Vandalism"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(comment).body == "Untouchable"
    end

    test "PUT behaves like PATCH", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        put(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Original comment body plus an edit"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Repo.reload!(comment).body == "Original comment body plus an edit"
    end

    test "for an unknown comment redirects to / with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        patch(conn, ~p"/images/#{image}/comments/999999999", %{
          "comment" => %{"body" => "Anything"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "does not update a comment through a different route image", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      other_image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original"})

      conn =
        patch(conn, ~p"/images/#{other_image}/comments/#{comment}", %{
          "comment" => %{"body" => "Changed"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"

      assert Repo.reload!(comment).body == "Original"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        patch(without_fingerprint(conn), ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Edited without a fingerprint"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(comment).body == "Original comment body"
    end
  end
end
