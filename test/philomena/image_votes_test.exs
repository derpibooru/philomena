defmodule Philomena.ImageVotesTest do
  use Philomena.DataCase

  alias Philomena.ImageVotes

  describe "image_votes" do
    alias Philomena.ImageVotes.ImageVote

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def image_vote_fixture(attrs \\ %{}) do
      {:ok, image_vote} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ImageVotes.create_image_vote()

      image_vote
    end

    test "list_image_votes/0 returns all image_votes" do
      image_vote = image_vote_fixture()
      assert ImageVotes.list_image_votes() == [image_vote]
    end

    test "get_image_vote!/1 returns the image_vote with given id" do
      image_vote = image_vote_fixture()
      assert ImageVotes.get_image_vote!(image_vote.id) == image_vote
    end

    test "create_image_vote/1 with valid data creates a image_vote" do
      assert {:ok, %ImageVote{} = image_vote} = ImageVotes.create_image_vote(@valid_attrs)
    end

    test "create_image_vote/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ImageVotes.create_image_vote(@invalid_attrs)
    end

    test "update_image_vote/2 with valid data updates the image_vote" do
      image_vote = image_vote_fixture()
      assert {:ok, %ImageVote{} = image_vote} = ImageVotes.update_image_vote(image_vote, @update_attrs)
    end

    test "update_image_vote/2 with invalid data returns error changeset" do
      image_vote = image_vote_fixture()
      assert {:error, %Ecto.Changeset{}} = ImageVotes.update_image_vote(image_vote, @invalid_attrs)
      assert image_vote == ImageVotes.get_image_vote!(image_vote.id)
    end

    test "delete_image_vote/1 deletes the image_vote" do
      image_vote = image_vote_fixture()
      assert {:ok, %ImageVote{}} = ImageVotes.delete_image_vote(image_vote)
      assert_raise Ecto.NoResultsError, fn -> ImageVotes.get_image_vote!(image_vote.id) end
    end

    test "change_image_vote/1 returns a image_vote changeset" do
      image_vote = image_vote_fixture()
      assert %Ecto.Changeset{} = ImageVotes.change_image_vote(image_vote)
    end
  end
end
