defmodule PhilomenaWeb.Image.FaveControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Multi
  alias Philomena.ImageFaves
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageVotes
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Repo

  defp interaction_path(image_id), do: ~p"/images/#{image_id}/fave"

  image_interaction_guard_tests([:post, :delete])

  defp fave(image, user) do
    Repo.one(from f in ImageFave, where: f.image_id == ^image.id and f.user_id == ^user.id)
  end

  defp vote(image, user) do
    Repo.one(from v in ImageVote, where: v.image_id == ^image.id and v.user_id == ^user.id)
  end

  defp fave!(image, user) do
    {:ok, _} =
      Multi.new()
      |> ImageFaves.put_fave_for_loaded_image(image, user)
      |> Multi.transact()
  end

  describe "POST /images/:image_id/fave" do
    setup :register_and_log_in_user

    test "records a fave plus an implicit upvote and returns interaction data",
         %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/fave")

      # NOTE: faving also upvotes the image
      assert json_response(conn, 200) == %{
               "score" => 1,
               "faves" => 1,
               "upvotes" => 1,
               "downvotes" => 0
             }

      assert fave(image, user)
      assert %ImageVote{up: true} = vote(image, user)
    end

    test "when the user had downvoted, replaces the downvote with an upvote",
         %{conn: conn, user: user} do
      image = image_fixture()

      {:ok, _} =
        Multi.new()
        |> ImageVotes.put_vote_for_loaded_image(image, user, false)
        |> Multi.transact()

      conn = post(conn, ~p"/images/#{image}/fave")

      assert json_response(conn, 200) == %{
               "score" => 1,
               "faves" => 1,
               "upvotes" => 1,
               "downvotes" => 0
             }

      assert %ImageVote{up: true} = vote(image, user)
    end

    test "a forced-filter match redirects without recording a fave", %{conn: conn, user: user} do
      image = image_fixture()
      filter = system_filter_fixture(hidden_complex_str: "id:#{image.id}")

      user
      |> Ecto.Changeset.change(forced_filter_id: filter.id)
      |> Repo.update!()

      conn = post(conn, ~p"/images/#{image}/fave")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You have been blocked from performing this action on this image."

      refute fave(image, user)
      refute vote(image, user)
    end
  end

  describe "DELETE /images/:image_id/fave" do
    setup :register_and_log_in_user

    test "removes the fave but keeps the implicit upvote", %{conn: conn, user: user} do
      image = image_fixture()
      fave!(image, user)

      {:ok, _} =
        Multi.new()
        |> ImageVotes.put_vote_for_loaded_image(image, user, true)
        |> Multi.transact()

      conn = delete(conn, ~p"/images/#{image}/fave")

      # NOTE: unfaving only deletes the fave row - the upvote that faving
      # created stays behind
      assert json_response(conn, 200) == %{
               "score" => 1,
               "faves" => 0,
               "upvotes" => 1,
               "downvotes" => 0
             }

      refute fave(image, user)
      assert %ImageVote{up: true} = vote(image, user)
    end

    test "with no existing fave still returns 200 interaction data", %{conn: conn} do
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/fave")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }
    end
  end
end
