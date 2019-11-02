defmodule Philomena.Filters.Filter do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Philomena.Tags.Tag
  alias Philomena.Images.Query
  alias Philomena.Users.User
  alias Philomena.Repo

  schema "filters" do
    belongs_to :user, User

    field :name, :string
    field :description, :string
    field :system, :boolean
    field :public, :boolean
    field :hidden_complex_str, :string
    field :spoilered_complex_str, :string
    field :hidden_tag_ids, {:array, :integer}, default: []
    field :spoilered_tag_ids, {:array, :integer}, default: []
    field :user_count, :integer, default: 0

    field :spoilered_tag_list, :string, virtual: true
    field :hidden_tag_list, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(filter, attrs) do
    filter
    |> cast(attrs, [:spoilered_tag_list, :hidden_tag_list, :description, :name, :spoilered_complex_str, :hidden_complex_str])
    |> propagate_tag_lists()
    |> validate_required([:name])
    |> unsafe_validate_unique([:user_id, :name], Repo)
    |> validate_my_downvotes(:spoilered_complex_str)
    |> validate_my_downvotes(:hidden_complex_str)
    |> validate_search(:spoilered_complex_str)
    |> validate_search(:hidden_complex_str)
  end

  def assign_tag_lists(filter) do
    tags = Enum.uniq(filter.spoilered_tag_ids ++ filter.hidden_tag_ids)

    lookup =
      Tag
      |> where([t], t.id in ^tags)
      |> Repo.all()
      |> Map.new(fn t -> {t.id, t.name} end)

    spoilered_tag_list =
      filter.spoilered_tag_ids
      |> Enum.map(&lookup[&1])
      |> Enum.filter(& &1 != nil)
      |> Enum.sort()
      |> Enum.join(", ")

    hidden_tag_list =
      filter.hidden_tag_ids
      |> Enum.map(&lookup[&1])
      |> Enum.filter(& &1 != nil)
      |> Enum.sort()
      |> Enum.join(", ")

    %{filter | hidden_tag_list: hidden_tag_list, spoilered_tag_list: spoilered_tag_list}
  end

  defp propagate_tag_lists(changeset) do
    spoilers = get_field(changeset, :spoilered_tag_list) |> parse_tag_list
    filters = get_field(changeset, :hidden_tag_list) |> parse_tag_list
    tags = Enum.uniq(spoilers ++ filters)

    lookup =
      Tag
      |> where([t], t.name in ^tags)
      |> Repo.all()
      |> Map.new(fn t -> {t.name, t.id} end)

    spoilered_tag_ids =
      spoilers
      |> Enum.map(&lookup[&1])
      |> Enum.filter(& &1 != nil)

    hidden_tag_ids =
      filters
      |> Enum.map(&lookup[&1])
      |> Enum.filter(& &1 != nil)

    changeset
    |> put_change(:spoilered_tag_ids, spoilered_tag_ids)
    |> put_change(:hidden_tag_ids, hidden_tag_ids)
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

  defp validate_search(changeset, field) do
    user_id = get_field(changeset, :user_id)

    if user_id do
      user = User |> Repo.get!(user_id)
      output = Query.user_parser(user, get_field(changeset, field))

      case output do
        {:ok, _} -> changeset
        _ ->
          changeset
          |> add_error(field, "is invalid")
      end
    else
      changeset
    end
  end

  defp parse_tag_list(list) do
    (list || "")
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
    |> Enum.filter(& &1 != "")
  end
end
