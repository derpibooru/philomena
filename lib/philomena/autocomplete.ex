defmodule Philomena.Autocomplete do
  @moduledoc """
  Pregenerated autocomplete files.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Tags.Tag
  alias Philomena.Images.Tagging
  alias Philomena.Autocomplete.Autocomplete

  @type tags_list() :: [{String.t(), number(), number()}]
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
    #     struct tag_reference {
    #       uint32_t tag_location;
    #       uint32_t num_uses;
    #     };
    #

    {ac_file, references} =
      Enum.reduce(tags, {<<>>, <<>>}, fn {name, images_count, _}, {file, references} ->
        pos = byte_size(file)
        assn = Map.get(associations, name, [])
        assn_bin = for id <- assn, into: <<>>, do: <<id::32-little>>

        {
          <<file::binary, byte_size(name)::8, name::binary, length(assn)::8, assn_bin::binary>>,
          <<references::binary, pos::32-little, images_count::32-little>>
        }
      end)

    ac_file = int32_align(ac_file)
    reference_start = byte_size(ac_file)

    # Finally add the reference start and number of tags in the footer
    #
    #     struct autocomplete_file {
    #       struct tag tags[];
    #       struct tag_reference references[];
    #       uint32_t format_version;
    #       uint32_t reference_start;
    #       uint32_t num_tags;
    #     };
    #

    ac_file =
      <<ac_file::binary, references::binary, 1::32-little, reference_start::32-little,
        length(tags)::32-little>>

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
    Tag
    |> select([t], {t.name, t.images_count, t.id})
    |> where([t], t.images_count > 0)
    |> order_by(desc: :images_count)
    |> limit(65_535)
    |> Repo.all()
    |> Enum.filter(fn {name, _, _} -> byte_size(name) < 255 end)
    |> Enum.sort()
  end

  #
  # Get up to eight associated tag ids for each returned tag.
  #
  @spec get_associations(tags_list()) :: assoc_map()
  defp get_associations(tags) do
    tags
    |> Enum.map(fn {name, images_count, id} ->
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
        |> Repo.all()

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
end
