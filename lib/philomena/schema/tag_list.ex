defmodule Philomena.Schema.TagList do
  # TODO: remove this in favor of normalized relations
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Changeset
  import Ecto.Query

  def assign_tag_list(model, field, target_field) do
    tags = model |> Map.get(field) |> Enum.uniq()

    lookup =
      Tag
      |> where([t], t.id in ^tags)
      |> order_by(asc: :name)
      |> Repo.all()
      |> Map.new(fn t -> {t.id, t.name} end)

    tag_list =
      model
      |> Map.get(field)
      |> Enum.map(&lookup[&1])
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    %{model | target_field => tag_list}
  end

  def propagate_tag_list(changeset, field, target_field) do
    tag_list = changeset |> get_field(field) |> parse_tag_list()

    lookup =
      Tag
      |> where([t], t.name in ^tag_list)
      |> Repo.all()
      |> Map.new(fn t -> {t.name, t.aliased_tag_id || t.id} end)

    tag_ids =
      tag_list
      |> Enum.map(&lookup[&1])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    changeset
    |> put_change(target_field, tag_ids)
  end

  defp parse_tag_list(list) do
    (list || "")
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
    |> Enum.filter(&(&1 != ""))
  end
end
