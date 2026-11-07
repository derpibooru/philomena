defmodule PhilomenaWeb.Api.Json.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments

  describe "GET /api/v1/json/comments/:id" do
    test "shows a signed comment", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "A signed comment"})

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      %{"comment" => body} = json_response(conn, 200)

      # NOTE: the avatar of a user without an uploaded avatar is a generated
      # SVG data URI, so it is asserted by shape only.
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => comment.id,
               "image_id" => image.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => "A signed comment",
               "created_at" => DateTime.to_iso8601(comment.created_at),
               "updated_at" => DateTime.to_iso8601(comment.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "hides the author of an anonymous comment", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Anon comment", "anonymous" => "true"})

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert %{"comment" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "attributes a fully anonymous comment to Background Pony", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil)

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert %{"comment" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "shows a hidden comment without its body or edit details", %{conn: conn} do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Rule-breaking comment"})

      {:ok, comment} =
        Comments.create_comment_hide(actor(moderator), image.id, comment.id, %{
          "deletion_reason" => "spam"
        })

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      %{"comment" => body} = json_response(conn, 200)
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => comment.id,
               "image_id" => image.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => nil,
               "created_at" => DateTime.to_iso8601(comment.created_at),
               "updated_at" => DateTime.to_iso8601(comment.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "shows a pending comment only to its author", %{conn: conn} do
      author = confirmed_user_fixture()
      image = image_fixture()

      comment =
        image
        |> comment_fixture(author, %{"body" => "Pending comment"})
        |> Ecto.Changeset.change(approved: false)
        |> Philomena.Repo.update!()

      assert json_response(get(conn, ~p"/api/v1/json/comments/#{comment.id}"), 404) ==
               %{"error" => "Not found"}

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}?key=#{author.authentication_token}")

      assert %{"comment" => %{"id" => id, "body" => "Pending comment"}} = json_response(conn, 200)
      assert id == comment.id
    end

    test "a moderator API key reads a hidden comment with redacted content", %{conn: conn} do
      moderator = moderator_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "Hidden body"})

      {:ok, _} =
        Comments.create_comment_hide(actor(moderator), image.id, comment.id, %{
          "deletion_reason" => "spam"
        })

      conn =
        get(
          conn,
          ~p"/api/v1/json/comments/#{comment.id}?key=#{moderator.authentication_token}"
        )

      assert %{"comment" => %{"id" => id, "body" => nil}} = json_response(conn, 200)
      assert id == comment.id
    end

    test "returns 404 for a destroyed comment", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil)

      {:ok, _} =
        Comments.create_comment_hide(actor(admin_user_fixture()), image.id, comment.id, %{
          "deletion_reason" => "spam"
        })

      {:ok, _} = Comments.create_comment_delete(actor(admin_user_fixture()), image.id, comment.id)

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 403 for a comment on a hidden image", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      comment = comment_fixture(image, moderator_user_fixture())

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert response(conn, 403) == ""
    end

    test "a moderator API key reads a hidden image comment with fully redacted metadata",
         %{conn: conn} do
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true)
      comment = comment_fixture(image, moderator, %{"body" => "Hidden image body"})

      conn =
        get(
          conn,
          ~p"/api/v1/json/comments/#{comment.id}?key=#{moderator.authentication_token}"
        )

      assert %{
               "comment" => %{
                 "id" => id,
                 "body" => nil,
                 "author" => nil,
                 "created_at" => nil
               }
             } = json_response(conn, 200)

      assert id == comment.id
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/comments/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/comments/not-a-number")
      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
