defmodule Philomena.Interactions do
  import Ecto.Query

  alias Philomena.ImageHides.ImageHide
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Repo

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

  defp union_all_queries([query]),
    do: query
  defp union_all_queries([query | rest]),
    do: query |> union_all(^union_all_queries(rest))
end