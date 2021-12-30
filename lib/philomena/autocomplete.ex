defmodule Philomena.Autocomplete do
  @moduledoc """
  Pregenerated autocomplete files.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Tags.Tag
  alias Philomena.Images.Tagging
  alias Philomena.Autocomplete.Autocomplete

  @type tags_list() :: [{String.t(), number(), number(), String.t() | nil}]
  @type assoc_map() :: %{String.t() => [number()]}

  @spec get_autocomplete() :: Autocomplete.t() | nil
  def get_autocomplete do
    Autocomplete
    |> order_by(desc: :created_at)
    |> limit(1)
    |> Repo.one()
  end

  def generate_autocomplete! do
    tags = get_tags()
    associations = get_associations(tags)

    # Tags are already sorted, so just add them to the file directly
    #
    #     struct tag {
    #       uint8_t key_length;
    #       uint8_t key[];
    #       uint8_t association_length;
    #       uint32_t associations[];
    #     };
    #

    {ac_file, name_locations} =
      Enum.reduce(tags, {<<>>, %{}}, fn {name, _, _, _}, {file, name_locations} ->
        pos = byte_size(file)
        assn = Map.get(associations, name, [])
        assn_bin = for id <- assn, into: <<>>, do: <<id::32-little>>

        {
          <<file::binary, byte_size(name)::8, name::binary, length(assn)::8, assn_bin::binary>>,
          Map.put(name_locations, name, pos)
        }
      end)

    # Link reference list; self-referential, so must be preprocessed to deal with aliases
    #
    #     struct tag_reference {
    #       uint32_t tag_location;
    #       uint8_t is_aliased : 1;
    #       union {
    #         uint32_t num_uses : 31;
    #         uint32_t alias_index : 31;
    #       };
    #     };
    #

    ac_file = int32_align(ac_file)
    reference_start = byte_size(ac_file)

    reference_indexes =
      tags
      |> Enum.with_index()
      |> Enum.map(fn {{name, _, _, _}, index} -> {name, index} end)
      |> Map.new()

    references =
      Enum.reduce(tags, <<>>, fn {name, images_count, _, alias_target}, references ->
        pos = Map.fetch!(name_locations, name)

        if not is_nil(alias_target) do
          target = Map.fetch!(reference_indexes, alias_target)

          <<references::binary, pos::32-little, -target::32-little>>
        else
          <<references::binary, pos::32-little, images_count::32-little>>
        end
      end)

    # Reorder tags by name in their namespace to provide a secondary ordering
    #
    #     struct secondary_reference {
    #         uint32_t primary_location;
    #     };
    #

    secondary_references =
      tags
      |> Enum.map(&{name_in_namespace(elem(&1, 0)), elem(&1, 0)})
      |> Enum.sort()
      |> Enum.reduce(<<>>, fn {_k, v}, secondary_references ->
        target = Map.fetch!(reference_indexes, v)

        <<secondary_references::binary, target::32-little>>
      end)

    # Finally add the reference start and number of tags in the footer
    #
    #     struct autocomplete_file {
    #       struct tag tags[];
    #       struct tag_reference primary_references[];
    #       struct secondary_reference secondary_references[];
    #       uint32_t format_version;
    #       uint32_t reference_start;
    #       uint32_t num_tags;
    #     };
    #

    ac_file = <<
      ac_file::binary,
      references::binary,
      secondary_references::binary,
      2::32-little,
      reference_start::32-little,
      length(tags)::32-little
    >>

    # Insert the autocomplete binary
    new_ac =
      %Autocomplete{}
      |> Autocomplete.changeset(%{content: ac_file})
      |> Repo.insert!()

    # Remove anything older
    Autocomplete
    |> where([ac], ac.created_at < ^new_ac.created_at)
    |> Repo.delete_all()
  end

  #
  # Get the names of tags and their number of uses as a map.
  # Sort is done in the application to avoid collation.
  #
  @spec get_tags() :: tags_list()
  defp get_tags do
    top_tags =
      Tag
      |> select([t], {t.name, t.images_count, t.id, nil})
      |> where([t], t.images_count > 0)
      |> order_by(desc: :images_count)
      |> limit(50_000)
      |> Repo.all()

    aliases_of_top_tags =
      Tag
      |> where([t], t.aliased_tag_id in ^Enum.map(top_tags, fn {_, _, id, _} -> id end))
      |> join(:inner, [t], _ in assoc(t, :aliased_tag))
      |> select([t, a], {t.name, 0, 0, a.name})
      |> Repo.all()

    (aliases_of_top_tags ++ top_tags)
    |> Enum.filter(fn {name, _, _, _} -> byte_size(name) < 255 end)
    |> Enum.sort()
  end

  #
  # Get up to eight associated tag ids for each returned tag.
  #
  @spec get_associations(tags_list()) :: assoc_map()
  defp get_associations(tags) do
    tags
    |> Enum.filter(fn {_, _, _, aliased} -> is_nil(aliased) end)
    |> Enum.map(fn {name, images_count, id, _} ->
      # Randomly sample 100 images with this tag
      image_sample =
        Tagging
        |> where(tag_id: ^id)
        |> select([it], it.image_id)
        |> order_by(asc: fragment("random()"))
        |> limit(100)

      # Select the tags from those images which have more uses than
      # the current one being considered, and overlap more than 50%
      assoc_ids =
        Tagging
        |> join(:inner, [it], _ in assoc(it, :tag))
        |> where([_, t], t.images_count > ^images_count)
        |> where([it, _], it.image_id in subquery(image_sample))
        |> group_by([_, t], t.id)
        |> order_by(desc: fragment("count(*)"))
        |> having([_, t], fragment("(100 * count(*)::float / LEAST(?, 100)) > 50", ^images_count))
        |> select([_, t], t.id)
        |> limit(8)
        |> Repo.all(timeout: 120_000)

      {name, assoc_ids}
    end)
    |> Map.new()
  end

  #
  # Right-pad a binary to be a multiple of 4 bytes.
  #
  @spec int32_align(binary()) :: binary()
  defp int32_align(bin) do
    pad_bits = 8 * (4 - rem(byte_size(bin), 4))

    <<bin::binary, 0::size(pad_bits)>>
  end

  #
  # Remove the artist:, oc: etc. prefix from a tag name,
  # if one is present.
  #
  @spec name_in_namespace(String.t()) :: String.t()
  defp name_in_namespace(s) do
    case String.split(s, ":", parts: 2, trim: true) do
      [_namespace, name] ->
        name

      [name] ->
        name

      _unknown ->
        s
    end
  end
end
