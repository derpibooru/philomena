defmodule Philomena.ModNotes.ModNote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "mod_notes" do
    belongs_to :moderator, User

    # fixme: rails polymorphic relation
    field :notable_id, :integer
    field :notable_type, :string

    field :body, :string

    field :notable, :any, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(mod_note, attrs) do
    mod_note
    |> cast(attrs, [:notable_id, :notable_type, :body])
    |> validate_required([:notable_id, :notable_type, :body])
    |> validate_inclusion(:notable_type, ["User", "Report", "DnpEntry"])
  end
end
