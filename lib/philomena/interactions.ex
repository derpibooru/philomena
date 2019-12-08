defmodule Philomena.Interactions do
  import Ecto.Query

  alias Philomena.ImageHides.ImageHide
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Images.Image
  alias Philomena.Repo
  alias Ecto.Multi

  def user_interactions(_images, nil),
    do: []

  def user_interactions(images, user) do
    ids =
      images 
      |> Enum.flat_map(fn
        nil -> []
        %{id: id} -> [id]
        enum -> Enum.map(enum, & &1.id)
      end)
      |> Enum.uniq()

    hide_interactions =
      ImageHide
      |> select([h], %{image_id: h.image_id, user_id: h.user_id, interaction_type: ^"hidden", value: ^""})
      |> where([h], h.image_id in ^ids)
      |> where(user_id: ^user.id)

    fave_interactions =
      ImageFave
      |> select([f], %{image_id: f.image_id, user_id: f.user_id, interaction_type: ^"faved", value: ^""})
      |> where([f], f.image_id in ^ids)
      |> where(user_id: ^user.id)

    upvote_interactions =
      ImageVote
      |> select([v], %{image_id: v.image_id, user_id: v.user_id, interaction_type: ^"voted", value: ^"up"})
      |> where([v], v.image_id in ^ids)
      |> where(user_id: ^user.id, up: true)

    downvote_interactions =
      ImageVote
      |> select([v], %{image_id: v.image_id, user_id: v.user_id, interaction_type: ^"voted", value: ^"down"})
      |> where([v], v.image_id in ^ids)
      |> where(user_id: ^user.id, up: false)

    [
      hide_interactions,
      fave_interactions,
      upvote_interactions,
      downvote_interactions
    ]
    |> union_all_queries()
    |> Repo.all()
  end

  def migrate_interactions(source, target) do
    now = DateTime.utc_now()
    source = Repo.preload(source, [:hiders, :favers, :upvoters, :downvoters])

    new_hides = Enum.map(source.hiders, &%{image_id: target.id, user_id: &1.id, created_at: now})
    new_faves = Enum.map(source.favers, &%{image_id: target.id, user_id: &1.id, created_at: now})
    new_upvotes = Enum.map(source.upvoters, &%{image_id: target.id, user_id: &1.id, created_at: now, up: true})
    new_downvotes = Enum.map(source.downvoters, &%{image_id: target.id, user_id: &1.id, created_at: now, up: false})

    Multi.new
    |> Multi.run(:hides, fn repo, %{} ->
      {count, nil} = repo.insert_all(ImageHide, new_hides, on_conflict: :nothing)

      {:ok, count}
    end)
    |> Multi.run(:faves, fn repo, %{} ->
      {count, nil} = repo.insert_all(ImageFave, new_faves, on_conflict: :nothing)

      {:ok, count}
    end)
    |> Multi.run(:upvotes, fn repo, %{} ->
      {count, nil} = repo.insert_all(ImageVote, new_upvotes, on_conflict: :nothing)

      {:ok, count}
    end)
    |> Multi.run(:downvotes, fn repo, %{} ->
      {count, nil} = repo.insert_all(ImageVote, new_downvotes, on_conflict: :nothing)

      {:ok, count}
    end)
    |> Multi.run(:image, fn repo, %{hides: hides, faves: faves, upvotes: upvotes, downvotes: downvotes} ->
      image_query = where(Image, id: ^target.id)

      repo.update_all(image_query, inc: [hides: hides, faves: faves, upvotes: upvotes, downvotes: downvotes, score: upvotes - downvotes])

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  defp union_all_queries([query]),
    do: query
  defp union_all_queries([query | rest]),
    do: query |> union_all(^union_all_queries(rest))
end