defmodule Philomena.DnpEntries.DnpEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  schema "dnp_entries" do
    belongs_to :requesting_user, User
    belongs_to :modifying_user, User
    belongs_to :tag, Tag

    field :aasm_state, :string, default: "requested"
    field :dnp_type, :string
    field :conditions, :string
    field :reason, :string
    field :hide_reason, :boolean, default: false
    field :instructions, :string
    field :feedback, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(dnp_entry, attrs) do
    dnp_entry
    |> cast(attrs, [])
    |> validate_required([])
  end
end
