defmodule PhilomenaWeb.Image.TamperControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.ImageVotes
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Repo

  # Records `voter`'s (up/down) vote on `image` through the vote context.
  defp cast_vote(image, voter, up) do
    {:ok, _} =
      Multi.new()
      |> ImageVotes.put_vote_for_loaded_image(image, voter, up)
      |> Multi.transact()

    :ok
  end

  defp voted?(image, voter) do
    Repo.exists?(from v in ImageVote, where: v.image_id == ^image.id and v.user_id == ^voter.id)
  end

  describe "POST /images/:image_id/tamper" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()
      voter = confirmed_user_fixture()
      cast_vote(image, voter, true)

      conn = post(conn, ~p"/images/#{image}/tamper", %{"user_id" => voter.id})

      assert redirected_to(conn) == ~p"/sessions/new"
      assert voted?(image, voter)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      voter = confirmed_user_fixture()
      cast_vote(image, voter, true)

      conn = post(conn, ~p"/images/#{image}/tamper", %{"user_id" => voter.id})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert voted?(image, voter)
    end

    test "as a moderator removes the named user's upvote", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      voter = confirmed_user_fixture()
      cast_vote(image, voter, true)

      conn = post(conn, ~p"/images/#{image}/tamper", %{"user_id" => voter.id})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Vote removed."
      refute voted?(image, voter)
    end

    test "as an admin removes the named user's downvote", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()
      voter = confirmed_user_fixture()
      cast_vote(image, voter, false)

      conn = post(conn, ~p"/images/#{image}/tamper", %{"user_id" => voter.id})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Vote removed."
      refute voted?(image, voter)
    end

    # Removing a vote that does not exist still succeeds (deletes zero rows).
    test "removing a non-existent vote still reports success", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      voter = confirmed_user_fixture()

      conn = post(conn, ~p"/images/#{image}/tamper", %{"user_id" => voter.id})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Vote removed."
    end

    # Missing image locators resolve to not-found before authorization.
    # redirecting rather than crashing.
    test "for an unknown user_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/tamper", %{"user_id" => 999_999_999})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      voter = confirmed_user_fixture()

      conn = post(conn, ~p"/images/not-a-number/tamper", %{"user_id" => voter.id})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
