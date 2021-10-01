defmodule Philomena.Filters.Filter do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Schema.TagList
  alias Philomena.Schema.Search
  alias Philomena.Users.User
  alias Philomena.Repo

  schema "filters" do
    belongs_to :user, User

    field :name, :string
    field :description, :string, default: ""
    field :system, :boolean
    field :public, :boolean
    field :hidden_complex_str, :string
    field :spoilered_complex_str, :string
    field :hidden_tag_ids, {:array, :integer}, default: []
    field :spoilered_tag_ids, {:array, :integer}, default: []
    field :user_count, :integer, default: 0

    field :spoilered_tag_list, :string, virtual: true
    field :hidden_tag_list, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(filter, attrs) do
    user =
      change(filter).data
      |> Repo.preload(:user)
      |> Map.get(:user)

    filter
    |> cast(attrs, [
      :spoilered_tag_list,
      :hidden_tag_list,
      :description,
      :name,
      :spoilered_complex_str,
      :hidden_complex_str
    ])
    |> validate_length(:description, max: 10_000, count: :bytes)
    |> TagList.propagate_tag_list(:spoilered_tag_list, :spoilered_tag_ids)
    |> TagList.propagate_tag_list(:hidden_tag_list, :hidden_tag_ids)
    |> validate_required([:name])
    |> validate_my_downvotes(:spoilered_complex_str)
    |> validate_my_downvotes(:hidden_complex_str)
    |> Search.validate_search(:spoilered_complex_str, user)
    |> Search.validate_search(:hidden_complex_str, user)
    |> unsafe_validate_unique([:user_id, :name], Repo)
  end

  def creation_changeset(filter, attrs) do
    filter
    |> cast(attrs, [:public])
    |> changeset(attrs)
  end

  def update_changeset(filter, attrs) do
    changeset(filter, strip_name_if_default(filter, attrs))
  end

  def deletion_changeset(filter) do
    filter
    |> change()
    |> foreign_key_constraint(:id, name: :fk_rails_d2b4c2768f)
  end

  def public_changeset(filter) do
    change(filter, public: true)
  end

  def hidden_tags_changeset(filter, hidden_tag_ids) do
    change(filter, hidden_tag_ids: hidden_tag_ids)
  end

  def spoilered_tags_changeset(filter, spoilered_tag_ids) do
    change(filter, spoilered_tag_ids: spoilered_tag_ids)
  end

  defp validate_my_downvotes(changeset, field) do
    value = get_field(changeset, field) || ""

    if String.match?(value, ~r/my:downvotes/i) do
      changeset
      |> add_error(field, "cannot contain my:downvotes")
    else
      changeset
    end
  end

  defp strip_name_if_default(%{system: true, name: "Default"}, attrs),
    do: Map.delete(attrs, "name")

  defp strip_name_if_default(_filter, attrs), do: attrs
end
