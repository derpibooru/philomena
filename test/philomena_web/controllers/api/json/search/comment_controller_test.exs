defmodule PhilomenaWeb.Api.Json.Search.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.RulesFixtures

  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Comment)
    :ok
  end

  describe "GET /api/v1/json/search/comments" do
    test "finds comments by body", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "chartreuse alpaca"})
      _other = comment_fixture(image, user, %{"body" => "unrelated"})
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/api/v1/json/search/comments?q=chartreuse")

      assert %{"total" => 1, "comments" => [found]} = json_response(conn, 200)

      assert %{"id" => id, "body" => "chartreuse alpaca", "image_id" => image_id} = found
      assert id == comment.id
      assert image_id == image.id
    end

    test "excludes hidden comments and comments on hidden images", %{conn: conn} do
      moderator = moderator_user_fixture()
      image = image_fixture()
      hidden_image = image_fixture(hidden_from_users: true)

      _visible = comment_fixture(image, nil, %{"body" => "chartreuse llama"})
      _on_hidden = comment_fixture(hidden_image, moderator, %{"body" => "chartreuse vicuna"})
      hidden = comment_fixture(image, moderator, %{"body" => "chartreuse guanaco"})

      {:ok, _} =
        Comments.create_comment_hide(actor(moderator), image.id, hidden.id, %{
          "deletion_reason" => "spam"
        })

      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/api/v1/json/search/comments?q=chartreuse")

      assert %{"total" => 1, "comments" => [%{"body" => "chartreuse llama"}]} =
               json_response(conn, 200)
    end

    test "excludes unapproved comments", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()

      # A body with an external link is withheld from approval when the
      # author is new.
      _rule = rule_fixture(name: "Approval")

      _unapproved =
        comment_fixture(image, user, %{"body" => "chartreuse https://spam.example/"})

      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/api/v1/json/search/comments?q=chartreuse")

      assert json_response(conn, 200) == %{"comments" => [], "total" => 0}
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results - not a 400.
      conn = get(conn, ~p"/api/v1/json/search/comments")

      assert json_response(conn, 200) == %{"comments" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/comments?q=)")

      assert json_response(conn, 400) == %{"error" => "Imbalanced parentheses."}
    end
  end
end
