defmodule PhilomenaWeb.Image.VoteControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Multi
  alias Philomena.ImageVotes
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Repo

  defp interaction_path(image_id), do: ~p"/images/#{image_id}/vote"

  image_interaction_guard_tests([:post, :delete])

  defp vote(image, user) do
    Repo.one(from v in ImageVote, where: v.image_id == ^image.id and v.user_id == ^user.id)
  end

  defp upvote!(image, user) do
    {:ok, _} =
      Multi.new()
      |> ImageVotes.put_vote_for_loaded_image(image, user, true)
      |> Multi.transact()
  end

  describe "POST /images/:image_id/vote" do
    setup :register_and_log_in_user

    test "with a JSON `up: true` body records an upvote and returns interaction data",
         %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => true})

      assert json_response(conn, 200) == %{
               "score" => 1,
               "faves" => 0,
               "upvotes" => 1,
               "downvotes" => 0
             }

      assert %ImageVote{up: true} = vote(image, user)
    end

    test "with a JSON `up: false` body records a downvote", %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => false})

      assert json_response(conn, 200) == %{
               "score" => -1,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 1
             }

      assert %ImageVote{up: false} = vote(image, user)
    end

    test "a form-encoded up=true body records an upvote", %{conn: conn, user: user} do
      # parse_up/1 accepts both the boolean `true` (from the JSON fetch client)
      # and the string "true" (from a form-encoded body), so a form-encoded
      # up=true now records an upvote.
      image = image_fixture()

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/images/#{image}/vote", "up=true")

      assert json_response(conn, 200) == %{
               "score" => 1,
               "faves" => 0,
               "upvotes" => 1,
               "downvotes" => 0
             }

      assert %ImageVote{up: true} = vote(image, user)
    end

    test "a form-encoded up=false body records a downvote", %{conn: conn, user: user} do
      image = image_fixture()

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/images/#{image}/vote", "up=false")

      assert json_response(conn, 200) == %{
               "score" => -1,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 1
             }

      assert %ImageVote{up: false} = vote(image, user)
    end

    test "with a missing `up` param returns 400 and records no vote",
         %{conn: conn, user: user} do
      # parse_up/1 only accepts true/"true"/false/"false"; a missing `up`
      # param is unparsable, so the controller returns 400 with an empty JSON
      # body and records nothing.
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/vote", %{})

      assert json_response(conn, 400) == %{"errors" => %{"up" => ["can't be blank"]}}
      refute vote(image, user)
    end

    test "with a junk `up` param returns 400 and records no vote",
         %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => "banana"})

      assert json_response(conn, 400) == %{"errors" => %{"up" => ["is invalid"]}}
      refute vote(image, user)
    end

    test "revoting replaces the existing vote", %{conn: conn, user: user} do
      image = image_fixture()
      upvote!(image, user)

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => false})

      assert json_response(conn, 200) == %{
               "score" => -1,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 1
             }

      assert %ImageVote{up: false} = vote(image, user)
    end

    test "a forced-filter match redirects without recording a vote", %{conn: conn, user: user} do
      image = image_fixture()
      filter = system_filter_fixture(hidden_complex_str: "id:#{image.id}")

      user
      |> Ecto.Changeset.change(forced_filter_id: filter.id)
      |> Repo.update!()

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => true})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You have been blocked from performing this action on this image."

      refute vote(image, user)
    end
  end

  describe "DELETE /images/:image_id/vote" do
    setup :register_and_log_in_user

    test "removes the user's vote and returns interaction data", %{conn: conn, user: user} do
      image = image_fixture()
      upvote!(image, user)

      conn = delete(conn, ~p"/images/#{image}/vote")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }

      refute vote(image, user)
    end

    test "with no existing vote still returns 200 interaction data", %{conn: conn} do
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/vote")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }
    end
  end
end
