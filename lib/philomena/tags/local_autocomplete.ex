defmodule Philomena.Tags.LocalAutocomplete do
  alias Philomena.Images.Tagging
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  defmodule Entry do
    @moduledoc """
    An individual entry record for autocomplete generation.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            images_count: integer(),
            id: integer(),
            alias_name: String.t() | nil
          }

    defstruct name: "",
              images_count: 0,
              id: 0,
              alias_name: nil
  end

  @type entry_list() :: [Entry.t()]

  @type tag_id :: integer()
  @type assoc_map() :: %{optional(String.t()) => [tag_id()]}

  @doc """
  Get a flat list of entry records for all of the top `amount` tags, and all of their
  aliases.
  """
  @spec get_tags(integer()) :: entry_list()
  def get_tags(amount) do
    tags = top_tags(amount)
    aliases = aliases_of_tags(tags)
    aliases ++ tags
  end

  @doc """
  Get a map of tag names to their most associated tag ids.

  For every tag entry, its associated tags satisfy the following properties:
  - is not the same as the entry's tag id
  - of a sample of 100 images, appear simultaneously more than 50% of the time
  """
  @spec get_associations(entry_list(), integer()) :: assoc_map()
  def get_associations(tags, amount) do
    tags
    |> Enum.filter(&is_nil(&1.alias_name))
    |> Map.new(&{&1.name, associated_tag_ids(&1, amount)})
  end

  defp top_tags(amount) do
    query =
      from t in Tag,
        where: t.images_count > 0,
        select: %Entry{name: t.name, images_count: t.images_count, id: t.id},
        order_by: [desc: :images_count],
        limit: ^amount

    Repo.all(query)
  end

  defp aliases_of_tags(tags) do
    ids = Enum.map(tags, & &1.id)

    query =
      from t in Tag,
        where: t.aliased_tag_id in ^ids,
        inner_join: a in assoc(t, :aliased_tag),
        select: %Entry{name: t.name, images_count: 0, id: 0, alias_name: a.name}

    Repo.all(query)
  end

  defp associated_tag_ids(entry, amount) do
    image_sample_query =
      from it in Tagging,
        where: it.tag_id == ^entry.id,
        select: it.image_id,
        order_by: [asc: fragment("random()")],
        limit: 100

    # Select the tags from those images which have more uses than
    # the current one being considered, and overlap more than 50%
    assoc_query =
      from it in Tagging,
        inner_join: t in assoc(it, :tag),
        where: t.images_count > ^entry.images_count,
        where: it.image_id in subquery(image_sample_query),
        group_by: t.id,
        order_by: [desc: fragment("count(*)")],
        having: fragment("(100 * count(*)::float / LEAST(?, 100)) > 50", ^entry.images_count),
        select: t.id,
        limit: ^amount

    Repo.all(assoc_query, timeout: 120_000)
  end
end
