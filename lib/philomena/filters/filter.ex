defmodule Philomena.Filters.Filter do
  use Ecto.Schema
  import Ecto.Changeset
  import PhilomenaQuery.Ecto.QueryValidator

  alias Philomena.Schema.TagList
  alias Philomena.Images.Query
  alias Philomena.Users.User
  alias Philomena.Tags.Tag
  alias Philomena.Repo

  @type t :: %__MODULE__{}

  schema "filters" do
    belongs_to :user, User

    field :name, :string
    field :description, :string, default: ""
    field :system, :boolean, default: false
    field :public, :boolean, default: false
    field :hidden_complex_str, :string, default: ""
    field :spoilered_complex_str, :string, default: ""
    field :hidden_tag_ids, {:array, :integer}, default: []
    field :spoilered_tag_ids, {:array, :integer}, default: []
    field :user_count, :integer, default: 0

    field :spoilered_tag_list, :string, virtual: true
    field :hidden_tag_list, :string, virtual: true
    field :recent, :boolean, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  @spec based_on(t() | nil) :: t()
  def based_on(filter) do
    filter = filter || %__MODULE__{}

    %__MODULE__{
      name: filter.name,
      description: filter.description,
      public: filter.public,
      hidden_complex_str: filter.hidden_complex_str,
      spoilered_complex_str: filter.spoilered_complex_str,
      hidden_tag_ids: filter.hidden_tag_ids,
      spoilered_tag_ids: filter.spoilered_tag_ids
    }
    |> TagList.assign_tag_list(:spoilered_tag_ids, :spoilered_tag_list)
    |> TagList.assign_tag_list(:hidden_tag_ids, :hidden_tag_list)
  end

  @doc false
  def changeset(filter, user, attrs \\ %{}) do
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
    |> validate_required([:name])
    |> validate_my_downvotes(:spoilered_complex_str)
    |> validate_my_downvotes(:hidden_complex_str)
    |> validate_query(:spoilered_complex_str, with: &Query.compile(&1, user: user, filter: true))
    |> validate_query(:hidden_complex_str, with: &Query.compile(&1, user: user, filter: true))
    |> unsafe_validate_unique([:user_id, :name], Repo)
  end

  @doc false
  def tag_names(changeset, field) when field in [:spoilered_tag_list, :hidden_tag_list] do
    changeset
    |> get_field(field)
    |> Tag.parse_tag_list()
  end

  @doc false
  def put_tag_ids(changeset, spoilered_tag_ids, hidden_tag_ids) do
    changeset
    |> put_change(:spoilered_tag_ids, spoilered_tag_ids)
    |> put_change(:hidden_tag_ids, hidden_tag_ids)
  end

  def creation_changeset(filter, user, attrs) do
    filter
    |> cast(attrs, [:public])
    |> changeset(user, attrs)
  end

  def update_changeset(filter, user, attrs) do
    filter
    |> changeset(user, attrs)
    |> validate_default_filter_name()
  end

  def deletion_changeset(filter) do
    filter
    |> change()
    |> foreign_key_constraint(:id, name: :fk_rails_d2b4c2768f)
    |> foreign_key_constraint(:id, name: :users_forced_filter_id_fkey)
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
      add_error(changeset, field, "cannot contain my:downvotes")
    else
      changeset
    end
  end

  defp validate_default_filter_name(%{data: %{system: true, name: "Default"}} = changeset) do
    if get_change(changeset, :name) do
      add_error(changeset, :name, "cannot be changed for the system-wide default filter")
    else
      changeset
    end
  end

  defp validate_default_filter_name(changeset), do: changeset
end
