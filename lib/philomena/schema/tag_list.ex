defmodule Philomena.Schema.TagList do
  # Remove when tag lists are converted to normalized relations.
  alias Philomena.Tags.Tag
  alias Philomena.Repo
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
end
