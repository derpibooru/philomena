defmodule PhilomenaWeb.Image.FavoriteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.ImageFaves
  alias Philomena.ImageVotes
  alias Philomena.Multi

  defp fave!(image, user) do
    {:ok, _} =
      Multi.new()
      |> ImageFaves.put_fave_for_loaded_image(image, user)
      |> Multi.transact()
  end

  defp upvote!(image, user) do
    {:ok, _} =
      Multi.new()
      |> ImageVotes.put_vote_for_loaded_image(image, user, true)
      |> Multi.transact()
  end

  describe "GET /images/:image_id/favorites" do
    test "renders the fave list without a layout for anonymous users", %{conn: conn} do
      image = image_fixture()
      faver = confirmed_user_fixture()
      fave!(image, faver)

      conn = get(conn, ~p"/images/#{image}/favorites")
      response = html_response(conn, 200)

      assert response =~ "Faved by"
      assert response =~ "1 user"
      assert response =~ faver.name
      # layout: false - the response is a bare partial, no page chrome
      refute response =~ "Derpibooru"
      # votes are only shown to users who can tamper (moderators)
      refute response =~ "Upvoted by"
    end

    test "hides votes from regular users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      upvote!(image, confirmed_user_fixture())

      conn = get(conn, ~p"/images/#{image}/favorites")
      response = html_response(conn, 200)

      assert response =~ "Faved by"
      refute response =~ "Upvoted by"
    end

    test "shows votes and hides to moderators", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      upvoter = confirmed_user_fixture()
      upvote!(image, upvoter)

      conn = get(conn, ~p"/images/#{image}/favorites")
      response = html_response(conn, 200)

      assert response =~ "Upvoted by"
      assert response =~ "Downvoted by"
      assert response =~ "Hidden by"
      assert response =~ upvoter.name
      # tamper links against each voter
      assert response =~ ~p"/images/#{image}/tamper?#{[user_id: upvoter.id]}"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/favorites")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
