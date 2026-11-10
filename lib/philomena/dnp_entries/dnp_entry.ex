defmodule Philomena.DnpEntries.DnpEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  @type t :: %__MODULE__{}

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

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(dnp_entry, attrs \\ %{}) do
    dnp_entry
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def update_changeset(dnp_entry, attrs, selectable_tag_ids) when is_list(selectable_tag_ids) do
    dnp_entry
    |> cast(attrs, [
      :conditions,
      :reason,
      :hide_reason,
      :instructions,
      :feedback,
      :dnp_type,
      :tag_id
    ])
    |> validate_required([:reason, :dnp_type])
    |> validate_inclusion(:dnp_type, types())
    |> validate_required(:tag_id, message: "must be one of your linked tags")
    |> validate_inclusion(:tag_id, selectable_tag_ids, message: "must be one of your linked tags")
    |> validate_conditions()
    |> foreign_key_constraint(:tag_id, name: "fk_rails_473a736b4a")
  end

  @doc false
  def update_changeset(dnp_entry, attrs, %Tag{} = tag) do
    dnp_entry
    |> cast(attrs, [
      :conditions,
      :reason,
      :hide_reason,
      :instructions,
      :feedback,
      :dnp_type
    ])
    |> put_change(:tag_id, tag.id)
    |> validate_required([:reason, :dnp_type])
    |> validate_inclusion(:dnp_type, types())
    |> validate_required(:tag_id, message: "must be one of your linked tags")
    |> validate_inclusion(:tag_id, [tag.id], message: "must be one of your linked tags")
    |> validate_conditions()
    |> foreign_key_constraint(:tag_id, name: "fk_rails_473a736b4a")
  end

  @doc false
  def creation_changeset(dnp_entry, attrs, %User{} = user, selectable_tag_ids)
      when is_list(selectable_tag_ids) do
    dnp_entry
    |> change(requesting_user_id: user.id)
    |> update_changeset(attrs, selectable_tag_ids)
  end

  @doc false
  def creation_changeset(dnp_entry, attrs, %User{} = user, %Tag{} = tag) do
    dnp_entry
    |> change(requesting_user_id: user.id)
    |> update_changeset(attrs, tag)
  end

  @doc false
  def fetch_tag_id(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:tag_id])
    |> validate_required(:tag_id)
    |> apply_action(:create)
    |> case do
      {:ok, %{tag_id: tag_id}} ->
        {:ok, tag_id}

      _ ->
        {:error, :not_found}
    end
  end

  def transition_changeset(dnp_entry, user, new_state) do
    dnp_entry
    |> change(modifying_user_id: user.id)
    |> change(aasm_state: new_state)
    |> validate_required([:aasm_state])
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

  def active_states do
    [
      "requested",
      "claimed",
      "rescinded",
      "acknowledged"
    ]
  end
end
