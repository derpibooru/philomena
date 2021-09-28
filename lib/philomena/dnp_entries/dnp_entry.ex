defmodule Philomena.DnpEntries.DnpEntry do
  use Ecto.Schema
  import Ecto.Changeset
  import Philomena.MarkdownWriter

  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  schema "dnp_entries" do
    belongs_to :requesting_user, User
    belongs_to :modifying_user, User
    belongs_to :tag, Tag

    field :aasm_state, :string, default: "requested"
    field :dnp_type, :string, default: ""
    field :conditions, :string, default: ""
    field :reason, :string, default: ""
    field :hide_reason, :boolean, default: false
    field :instructions, :string, default: ""
    field :feedback, :string, default: ""
    field :conditions_md, :string, default: ""
    field :reason_md, :string, default: ""
    field :instructions_md, :string, default: ""

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(dnp_entry, attrs) do
    dnp_entry
    |> cast(attrs, [])
    |> validate_required([])
  end

  def update_changeset(dnp_entry, attrs, tag) do
    dnp_entry
    |> cast(attrs, [:conditions, :reason, :hide_reason, :instructions, :feedback, :dnp_type])
    |> put_change(:tag_id, tag.id)
    |> validate_required([:reason, :dnp_type])
    |> validate_inclusion(:dnp_type, types())
    |> validate_conditions()
    |> put_markdown(attrs, :conditions, :conditions_md)
    |> put_markdown(attrs, :reason, :reason_md)
    |> put_markdown(attrs, :instructions, :instructions_md)
    |> foreign_key_constraint(:tag_id, name: "fk_rails_473a736b4a")
  end

  def creation_changeset(dnp_entry, attrs, tag, user) do
    dnp_entry
    |> change(requesting_user_id: user.id)
    |> update_changeset(attrs, tag)
  end

  def transition_changeset(dnp_entry, user, new_state) do
    dnp_entry
    |> change(modifying_user_id: user.id)
    |> change(aasm_state: new_state)
    |> validate_inclusion(:aasm_state, states())
  end

  defp validate_conditions(%Ecto.Changeset{changes: %{dnp_type: "Other"}} = changeset),
    do: validate_required(changeset, [:conditions])

  defp validate_conditions(changeset),
    do: changeset

  def types do
    reasons()
    |> Enum.map(fn {title, _desc} -> title end)
  end

  def reasons do
    [
      {"No Edits",
       "I would like to prevent edited versions of my artwork from being uploaded in the future"},
      {"Artist Tag Change",
       "I would like my artist tag to be changed to something that can not be connected to my current name"},
      {"Uploader Credit Change",
       "I would like the uploader credit for already existing uploads of my art to be assigned to me"},
      {"Certain Type/Location Only",
       "I only want to allow art of a certain type or from a certain location to be uploaded to Derpibooru"},
      {"With Permission Only",
       "I only want people with my permission to be allowed to upload my art to Derpibooru"},
      {"Artist Upload Only",
       "I want to be the only person allowed to upload my art to Derpibooru"},
      {"Other", "I would like a DNP entry under other conditions"}
    ]
  end

  def states do
    [
      "requested",
      "claimed",
      "listed",
      "rescinded",
      "acknowledged",
      "closed"
    ]
  end
end
