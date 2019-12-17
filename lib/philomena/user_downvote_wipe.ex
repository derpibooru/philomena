defmodule Philomena.UserDownvoteWipe do
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.Repo
  import Ecto.Query

  def perform(user, upvotes_and_faves_too \\ false) do
    ImageVote
    |> where(user_id: ^user.id, up: false)
    |> in_batches(fn queryable, image_ids ->
      Repo.delete_all(where(queryable, [iv], iv.image_id in ^image_ids))
      Repo.update_all(where(Image, [i], i.id in ^image_ids), inc: [downvotes_count: -1, score: 1])
      Images.reindex_images(image_ids)

      # Allow time for indexing to catch up
      :timer.sleep(:timer.seconds(10))
    end)

    if upvotes_and_faves_too do
      ImageVote
      |> where(user_id: ^user.id, up: true)
      |> in_batches(fn queryable, image_ids ->
        Repo.delete_all(where(queryable, [iv], iv.image_id in ^image_ids))
        Repo.update_all(where(Image, [i], i.id in ^image_ids), inc: [upvotes_count: -1, score: -1])
        Images.reindex_images(image_ids)
  
        :timer.sleep(:timer.seconds(10))
      end)

      ImageFave
      |> where(user_id: ^user.id)
      |> in_batches(fn queryable, image_ids ->
        Repo.delete_all(where(queryable, [iv], iv.image_id in ^image_ids))
        Repo.update_all(where(Image, [i], i.id in ^image_ids), inc: [faves_count: -1])
        Images.reindex_images(image_ids)
  
        :timer.sleep(:timer.seconds(10))
      end)
    end
  end

  # todo: extract this to its own module somehow
  defp in_batches(queryable, mapper) do
    queryable = order_by(queryable, asc: :image_id)

    ids =
      queryable
      |> select([q], q.image_id)
      |> limit(1000)
      |> Repo.all()

    queryable
    |> in_batches(mapper, 1000, ids)
  end

  defp in_batches(_queryable, _mapper, _batch_size, []), do: nil

  defp in_batches(queryable, mapper, batch_size, ids) do
    mapper.(exclude(queryable, :order_by), ids)

    ids =
      queryable
      |> where([q], q.image_id > ^Enum.max(ids))
      |> select([q], q.image_id)
      |> limit(^batch_size)
      |> Repo.all()

    in_batches(queryable, mapper, batch_size, ids)
  end
end
