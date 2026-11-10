defmodule Philomena.Users.QueryForm do
  use Ecto.Schema

  import Ecto.Changeset
  import PhilomenaQuery.Ecto.QueryValidator

  alias Philomena.Users.Query

  @type t :: %__MODULE__{}

  embedded_schema do
    field :query, :string
    field :sf, :string, default: "id"
    field :sd, :string, default: "desc"

    field :compiled_query, :map, virtual: true
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:query, :sf, :sd])
    |> validate_inclusion(:sf, ~W(
      id
      name
      confirmed_at
      updated_at
      deleted_at
      images_count
      image_faves_count
      comments_count
      image_votes_count
      metadata_updates_count
      posts_count
      topics_count
      _score
    ))
    |> validate_inclusion(:sd, ~w(asc desc))
    |> validate_required([:sf, :sd])
    |> validate_query(:query, with: &Query.compile/1, default: "*", into: :compiled_query)
  end
end
