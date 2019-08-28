defmodule Philomena.ModNotes.ModNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mod_notes" do
    belongs_to :moderator, Philomena.Users.User

    # fixme: rails polymorphic relation
    field :notable_id, :integer
    field :notable_type, :string

    field :body, :string
    field :deleted, :boolean, default: false

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(mod_note, attrs) do
    mod_note
    |> cast(attrs, [])
    |> validate_required([])
  end
end
