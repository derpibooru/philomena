defmodule PhilomenaWeb.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Comments.Comment
  alias Philomena.Repo

  setup do
    Search.clear_index!(Comment)
    :ok
  end

  describe "GET /comments" do
    test "renders recent comments for anonymous users", %{conn: conn} do
      image = image_fixture()
      _comment = comment_fixture(image, nil, %{"body" => "Test searchable comment body"})
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments")
      response = html_response(conn, 200)

      assert response =~ "Comments - Derpibooru"
      assert response =~ "Test searchable comment body"
      assert response =~ ~p"/images/#{image.id}"
    end

    test "does not show hidden comments to anonymous users", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test hidden comment body"})

      comment
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments")
      response = html_response(conn, 200)

      refute response =~ "Test hidden comment body"
    end

    test "does not show comments on hidden images to anonymous users", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)

      _comment =
        comment_fixture(image, moderator_user_fixture(), %{"body" => "Test orphaned comment body"})

      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments")
      response = html_response(conn, 200)

      refute response =~ "Test orphaned comment body"
    end

    test "filters comments with the cq parameter", %{conn: conn} do
      image = image_fixture()
      _matching = comment_fixture(image, nil, %{"body" => "Test grapefruit comment"})
      _other = comment_fixture(image, nil, %{"body" => "Test kumquat comment"})
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments?cq=grapefruit")
      response = html_response(conn, 200)

      assert response =~ "Test grapefruit comment"
      refute response =~ "Test kumquat comment"
    end

    test "renders an error for an invalid cq query", %{conn: conn} do
      conn = get(conn, ~p"/comments?cq=created_at.gte:not-a-date")
      response = html_response(conn, 200)

      assert response =~ "Comments - Derpibooru"
    end

    test "renders moderation actions, deleted moderator, and identity for staff", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Hidden searchable body"})
      moderator = moderator_user_fixture(%{name: "Search Comment Deleter"})

      {:ok, _comment} =
        Comments.create_comment_hide(
          actor(moderator),
          image.id,
          comment.id,
          %{"deletion_reason" => "Search policy violation"}
        )

      comment =
        Repo.update!(
          Ecto.Changeset.change(comment,
            ip: %Postgrex.INET{address: {192, 0, 2, 44}, netmask: 32},
            fingerprint: "searchfp1234"
          )
        )

      SearchHelpers.reindex_all!(Comment)

      conn =
        conn
        |> log_in_user(moderator)
        |> get(~p"/comments?cq=id:#{comment.id}")

      response = html_response(conn, 200)

      assert response =~ "Hidden searchable body"
      assert response =~ "Search policy violation"
      assert response =~ moderator.name
      assert response =~ "Restore"
      assert response =~ ~p"/images/#{image}/comments/#{comment}/delete"
      assert response =~ "Delete Contents"
      assert response =~ "192.0.2.44"
      assert response =~ "searchf"
    end

    test "does not render comment identity metadata for a regular user", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Public searchable body"})

      Repo.update!(
        Ecto.Changeset.change(comment,
          ip: %Postgrex.INET{address: {192, 0, 2, 45}, netmask: 32},
          fingerprint: "regularfp1234"
        )
      )

      SearchHelpers.reindex_all!(Comment)

      response =
        conn
        |> get(~p"/comments?cq=id:#{comment.id}")
        |> html_response(200)

      assert response =~ "Public searchable body"
      refute response =~ "192.0.2.45"
      refute response =~ "regularf"
      refute response =~ "regularfp1234"
    end

    test "renders destroyed state without the original body for staff", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Destroyed searchable body"})
      moderator = moderator_user_fixture()

      {:ok, _comment} =
        Comments.create_comment_hide(
          actor(moderator),
          image.id,
          comment.id,
          %{"deletion_reason" => "Destroyed search body"}
        )

      {:ok, _comment} = Comments.create_comment_delete(actor(moderator), image.id, comment.id)
      SearchHelpers.reindex_all!(Comment)

      response =
        conn
        |> log_in_user(moderator)
        |> get(~p"/comments?cq=id:#{comment.id}")
        |> html_response(200)

      assert response =~ "This comment's contents have been destroyed."
      refute response =~ "Destroyed searchable body"
      refute response =~ "Delete Contents"
    end
  end
end
