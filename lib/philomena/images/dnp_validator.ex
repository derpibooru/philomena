defmodule Philomena.Images.DnpValidator do
  import Ecto.Changeset
  import Ecto.Query
  alias Philomena.Repo
  alias Philomena.Tags.Tag
  alias Philomena.ArtistLinks.ArtistLink

  def validate_dnp(changeset, uploader) do
    tags =
      changeset
      |> get_field(:tags)
      |> extract_tags()

    edit_present? = MapSet.member?(tags, "edit")

    tags_with_dnp =
      Tag
      |> where([t], t.name in ^extract_artists(tags))
      |> preload(dnp_entries: :requesting_user)
      |> Repo.all()
      |> Enum.filter(&(length(&1.dnp_entries) > 0))

    changeset
    |> validate_artist_only(tags_with_dnp, uploader)
    |> validate_no_edits(tags_with_dnp, uploader, edit_present?)
  end

  defp validate_artist_only(changeset, tags_with_dnp, uploader) do
    Enum.reduce(tags_with_dnp, changeset, fn tag, changeset ->
      case Enum.any?(
             tag.dnp_entries,
             &(&1.dnp_type == "Artist Upload Only" and not valid_user?(&1, uploader))
           ) do
        true ->
          add_error(changeset, :image, "DNP (Artist upload only)")

        false ->
          changeset
      end
    end)
  end

  defp validate_no_edits(changeset, _tags_with_dnp, _uploader, false), do: changeset

  defp validate_no_edits(changeset, tags_with_dnp, uploader, true) do
    Enum.reduce(tags_with_dnp, changeset, fn tag, changeset ->
      case Enum.any?(
             tag.dnp_entries,
             &(&1.dnp_type == "No Edits" and not valid_user?(&1, uploader))
           ) do
        true ->
          add_error(changeset, :image, "DNP (No edits)")

        false ->
          changeset
      end
    end)
  end

  defp valid_user?(_dnp_entry, nil), do: false

  defp valid_user?(dnp_entry, user) do
    ArtistLink
    |> where(tag_id: ^dnp_entry.tag_id)
    |> where(aasm_state: "verified")
    |> where(user_id: ^user.id)
    |> Repo.exists?()
  end

  defp extract_tags(tags) do
    tags
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp extract_artists(tags) do
    Enum.filter(tags, &String.starts_with?(&1, "artist:"))
  end
end
