defmodule Philomena.Images.DnpValidator do
  import Ecto.Changeset
  import Ecto.Query
  alias Philomena.Repo
  alias Philomena.Tags.Tag
  alias Philomena.DnpEntries.DnpEntry

  def validate_dnp(changeset, uploader) do
    tags =
      changeset
      |> get_field(:tags)
      |> Enum.map(& &1.name)

    edit_present? = "edit" in tags

    tags_with_dnp =
      Tag
      |> from(as: :tag)
      |> where([t], t.name in ^tags)
      |> where(exists(where(DnpEntry, [d], d.tag_id == parent_as(:tag).id)))
      |> preload(dnp_entries: [tag: :verified_links])
      |> Repo.all()

    changeset
    |> validate_artist_only(tags_with_dnp, uploader)
    |> validate_no_edits(tags_with_dnp, uploader, edit_present?)
  end

  defp validate_artist_only(changeset, tags_with_dnp, uploader) do
    validate_tags_with_dnp(changeset, tags_with_dnp, uploader, "Artist Upload Only")
  end

  defp validate_no_edits(changeset, tags_with_dnp, uploader, edit_present?) do
    if edit_present? do
      validate_tags_with_dnp(changeset, tags_with_dnp, uploader, "No Edits")
    else
      changeset
    end
  end

  defp validate_tags_with_dnp(changeset, tags_with_dnp, uploader, dnp_type) do
    Enum.reduce(tags_with_dnp, changeset, fn tag, changeset ->
      tag.dnp_entries
      |> Enum.any?(&(&1.dnp_type == dnp_type and not uploader_permitted?(&1, uploader)))
      |> case do
        true ->
          add_error(changeset, :image, "DNP (#{dnp_type})")

        _ ->
          changeset
      end
    end)
  end

  defp uploader_permitted?(dnp_entry, uploader) do
    case uploader do
      %{id: uploader_id} ->
        Enum.any?(dnp_entry.tag.verified_links, &(&1.user_id == uploader_id))

      _ ->
        false
    end
  end
end
