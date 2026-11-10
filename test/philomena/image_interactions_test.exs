defmodule Philomena.ImageInteractionsTest do
  use Philomena.DataCase, async: true

  alias Philomena.Multi
  alias Philomena.ImageFaves
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageHides
  alias Philomena.ImageHides.ImageHide
  alias Philomena.ImageIntensities
  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.ImageVotes
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Interactions
  alias PhilomenaMedia.Intensities

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  defp transact(multi) do
    assert {:ok, changes} = Multi.transact(multi)
    changes
  end

  test "favorite replacement and deletion keep image and user counters idempotent" do
    image = image_fixture()
    user = confirmed_user_fixture()

    put = fn ->
      Multi.new()
      |> ImageFaves.put_fave_for_loaded_image(image, user)
      |> transact()
    end

    put.()
    put.()

    assert Repo.aggregate(
             from(f in ImageFave, where: f.image_id == ^image.id and f.user_id == ^user.id),
             :count
           ) == 1

    assert Repo.reload!(image).faves_count == 1
    assert Repo.reload!(user).image_faves_count == 1

    delete = fn ->
      Multi.new()
      |> ImageFaves.delete_fave_for_loaded_image(image, user)
      |> transact()
    end

    assert %{unfave: {1, nil}} = delete.()
    assert %{unfave: {0, nil}} = delete.()
    assert Repo.reload!(image).faves_count == 0
    assert Repo.reload!(user).image_faves_count == 0
  end

  test "hide replacement and deletion keep the image counter idempotent" do
    image = image_fixture()
    user = confirmed_user_fixture()

    for _ <- 1..2 do
      Multi.new()
      |> ImageHides.put_hide_for_loaded_image(image, user)
      |> transact()
    end

    assert Repo.aggregate(
             from(h in ImageHide, where: h.image_id == ^image.id and h.user_id == ^user.id),
             :count
           ) == 1

    assert Repo.reload!(image).hides_count == 1

    assert %{unhide: {1, nil}} =
             Multi.new()
             |> ImageHides.delete_hide_for_loaded_image(image, user)
             |> transact()

    assert %{unhide: {0, nil}} =
             Multi.new()
             |> ImageHides.delete_hide_for_loaded_image(image, user)
             |> transact()

    assert Repo.reload!(image).hides_count == 0
  end

  test "vote replacement handles retries, direction changes, and repeated deletion" do
    image = image_fixture()
    user = confirmed_user_fixture()

    vote = fn up ->
      Multi.new()
      |> ImageVotes.put_vote_for_loaded_image(image, user, up)
      |> transact()
    end

    vote.(false)
    assert %ImageVote{up: false} = Repo.get_by(ImageVote, image_id: image.id, user_id: user.id)
    assert %{downvotes_count: 1, upvotes_count: 0, score: -1} = Repo.reload!(image)

    vote.(true)
    vote.(true)

    assert %ImageVote{up: true} = Repo.get_by(ImageVote, image_id: image.id, user_id: user.id)
    assert %{downvotes_count: 0, upvotes_count: 1, score: 1} = Repo.reload!(image)
    assert Repo.reload!(user).image_votes_count == 1

    delete = fn ->
      Multi.new()
      |> ImageVotes.delete_vote_for_loaded_image(image, user)
      |> transact()
    end

    assert %{unupvote: {1, nil}, undownvote: {0, nil}} = delete.()
    assert %{unupvote: {0, nil}, undownvote: {0, nil}} = delete.()
    assert %{downvotes_count: 0, upvotes_count: 0, score: 0} = Repo.reload!(image)
    assert Repo.reload!(user).image_votes_count == 0
  end

  test "derived intensities replace the one row owned by an image" do
    image = image_fixture()

    assert {:ok, %ImageIntensity{}} =
             ImageIntensities.put_for_loaded_image(
               image,
               %Intensities{nw: 1.0, ne: 2.0, sw: 3.0, se: 4.0}
             )

    assert {:ok, %ImageIntensity{}} =
             ImageIntensities.put_for_loaded_image(
               image,
               %Intensities{nw: 5.0, ne: 6.0, sw: 7.0, se: 8.0}
             )

    assert [%ImageIntensity{nw: 5.0, ne: 6.0, sw: 7.0, se: 8.0}] =
             Repo.all(from(i in ImageIntensity, where: i.image_id == ^image.id))

    Repo.delete!(image)
    refute Repo.exists?(from i in ImageIntensity, where: i.image_id == ^image.id)
  end

  test "actor reads normalize nested images and omit absent interactions" do
    user = confirmed_user_fixture()
    image = image_fixture()
    other_image = image_fixture()
    untouched = image_fixture()

    Multi.new()
    |> ImageFaves.put_fave_for_loaded_image(image, user)
    |> ImageVotes.put_vote_for_loaded_image(image, user, true)
    |> ImageHides.put_hide_for_loaded_image(other_image, user)
    |> transact()

    interactions =
      Interactions.user_interactions(actor(user), [
        nil,
        image,
        image.id,
        [{image, %{sort: []}}, [other_image, untouched]]
      ])

    assert interactions
           |> Enum.map(&{&1.image_id, &1.interaction_type, &1.value})
           |> Enum.sort() ==
             [
               {image.id, "faved", ""},
               {image.id, "voted", "up"},
               {other_image.id, "hidden", ""}
             ]
             |> Enum.sort()

    assert Interactions.user_interactions(actor(), [image]) == []
  end

  test "merge migration keeps target collisions and applies inserted-row counter deltas" do
    source = image_fixture()
    target = image_fixture()
    source_only = confirmed_user_fixture()
    collision = confirmed_user_fixture()
    downvote_only = confirmed_user_fixture()

    Multi.new()
    |> ImageHides.put_hide_for_loaded_image(source, source_only)
    |> ImageFaves.put_fave_for_loaded_image(source, source_only)
    |> ImageVotes.put_vote_for_loaded_image(source, source_only, true)
    |> transact()

    Multi.new()
    |> ImageHides.put_hide_for_loaded_image(source, collision)
    |> ImageFaves.put_fave_for_loaded_image(source, collision)
    |> ImageVotes.put_vote_for_loaded_image(source, collision, true)
    |> transact()

    Multi.new()
    |> ImageVotes.put_vote_for_loaded_image(source, downvote_only, false)
    |> transact()

    Multi.new()
    |> ImageHides.put_hide_for_loaded_image(target, collision)
    |> ImageFaves.put_fave_for_loaded_image(target, collision)
    |> ImageVotes.put_vote_for_loaded_image(target, collision, false)
    |> transact()

    assert %{
             interaction_hides: 1,
             interaction_faves: {1, _},
             interaction_upvotes: {1, _},
             interaction_downvotes: {1, _},
             interaction_image: 1
           } =
             Multi.new()
             |> Interactions.migrate_loaded_images(source, target)
             |> transact()

    assert Repo.get_by(ImageHide, image_id: target.id, user_id: source_only.id)
    assert Repo.get_by(ImageFave, image_id: target.id, user_id: source_only.id)

    assert %ImageVote{up: true} =
             Repo.get_by(ImageVote, image_id: target.id, user_id: source_only.id)

    assert %ImageVote{up: false} =
             Repo.get_by(ImageVote, image_id: target.id, user_id: collision.id)

    assert %ImageVote{up: false} =
             Repo.get_by(ImageVote, image_id: target.id, user_id: downvote_only.id)

    assert %{
             hides_count: 2,
             faves_count: 2,
             upvotes_count: 1,
             downvotes_count: 2,
             score: -1
           } = Repo.reload!(target)

    assert Repo.get_by(ImageHide, image_id: source.id, user_id: source_only.id)
    assert Repo.reload!(source_only).image_faves_count == 2
    assert Repo.reload!(source_only).image_votes_count == 2
    assert Repo.reload!(collision).image_faves_count == 2
    assert Repo.reload!(collision).image_votes_count == 2
    assert Repo.reload!(downvote_only).image_votes_count == 2
  end
end
