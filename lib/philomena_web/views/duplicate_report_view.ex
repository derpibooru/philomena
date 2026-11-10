defmodule PhilomenaWeb.DuplicateReportView do
  use PhilomenaWeb, :view

  alias Philomena.DuplicateReports.Comparison
  alias PhilomenaWeb.ImageView

  def comparison_url(conn, image),
    do: ImageView.thumb_url(image, can?(conn, :show, image), :full)

  defdelegate largest_dimensions(images), to: Comparison

  def states do
    [
      {"Open", "open"},
      {"Claimed", "claimed"},
      {"Accepted", "accepted"},
      {"Rejected", "rejected"}
    ]
  end

  def sorts do
    [
      [key: "Ascending", value: "asc"],
      [key: "Descending", value: "desc"]
    ]
  end

  def background_class(%{state: "rejected"}), do: "background-danger"
  def background_class(%{state: "accepted"}), do: "background-success"
  def background_class(%{state: "claimed"}), do: "background-warning"
  def background_class(_duplicate_report), do: nil

  def file_types(%{image: image, duplicate_of_image: duplicate_of_image}) do
    source_type = String.upcase(to_string(image.image_format))
    target_type = String.upcase(to_string(duplicate_of_image.image_format))

    "(#{source_type}, #{target_type})"
  end

  defdelegate forward_merge?(report), to: Comparison
  defdelegate higher_res?(report), to: Comparison
  defdelegate same_res?(report), to: Comparison
  defdelegate same_format?(report), to: Comparison
  defdelegate better_format?(report), to: Comparison
  defdelegate same_aspect_ratio?(report), to: Comparison
  defdelegate neither_have_source?(report), to: Comparison
  defdelegate same_source?(report), to: Comparison
  defdelegate similar_source?(report), to: Comparison
  defdelegate source_on_target?(report), to: Comparison
  defdelegate source_on_source?(report), to: Comparison
  defdelegate same_artist_tags?(report), to: Comparison
  defdelegate more_artist_tags_on_target?(report), to: Comparison
  defdelegate more_artist_tags_on_source?(report), to: Comparison
  defdelegate same_rating_tags?(report), to: Comparison
  defdelegate target_is_edit?(report), to: Comparison
  defdelegate source_is_edit?(report), to: Comparison
  defdelegate both_are_edits?(report), to: Comparison
  defdelegate target_is_alternate_version?(report), to: Comparison
  defdelegate source_is_alternate_version?(report), to: Comparison
  defdelegate both_are_alternate_versions?(report), to: Comparison
  defdelegate mergeable?(report), to: Comparison
  defdelegate source_approved?(report), to: Comparison
  defdelegate target_approved?(report), to: Comparison
end
