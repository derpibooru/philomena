defmodule Philomena.DuplicateReports.Comparison do
  @moduledoc """
  Domain comparisons between the source and target images of a duplicate report.

  These predicates describe resolution, format, provenance, tag, version, and
  merge eligibility independently of how a report is rendered.
  """

  @formats_order ~W(video/webm image/svg+xml image/png image/gif image/jpeg other)

  def largest_dimensions(images) do
    images
    |> Enum.map(&{&1.image_width, &1.image_height})
    |> Enum.max_by(fn {width, height} -> width * height end)
  end

  def forward_merge?(%{image_id: image_id, duplicate_of_image_id: duplicate_of_image_id}),
    do: duplicate_of_image_id > image_id

  def higher_res?(%{image: image, duplicate_of_image: target}),
    do: target.image_width > image.image_width or target.image_height > image.image_height

  def same_res?(%{image: image, duplicate_of_image: target}),
    do: target.image_width == image.image_width and target.image_height == image.image_height

  def same_format?(%{image: image, duplicate_of_image: target}),
    do: target.image_mime_type == image.image_mime_type

  def better_format?(%{image: image, duplicate_of_image: target}) do
    format_index(target.image_mime_type) < format_index(image.image_mime_type)
  end

  def same_aspect_ratio?(%{image: image, duplicate_of_image: target}),
    do: abs(target.image_aspect_ratio - image.image_aspect_ratio) <= 0.009

  def neither_have_source?(%{image: image, duplicate_of_image: target}),
    do: Enum.empty?(target.sources) and Enum.empty?(image.sources)

  def same_source?(%{image: image, duplicate_of_image: target}),
    do: MapSet.equal?(MapSet.new(image.sources), MapSet.new(target.sources))

  def similar_source?(%{image: image, duplicate_of_image: target}) do
    MapSet.equal?(
      MapSet.new(image.sources, &URI.parse(&1.source).host),
      MapSet.new(target.sources, &URI.parse(&1.source).host)
    )
  end

  def source_on_target?(%{image: image, duplicate_of_image: target}),
    do: Enum.any?(target.sources) and Enum.empty?(image.sources)

  def source_on_source?(%{image: image, duplicate_of_image: target}),
    do: Enum.empty?(target.sources) and Enum.any?(image.sources)

  def same_artist_tags?(%{image: image, duplicate_of_image: target}),
    do: MapSet.equal?(artist_tags(image), artist_tags(target))

  def more_artist_tags_on_target?(%{image: image, duplicate_of_image: target}),
    do: proper_subset?(artist_tags(image), artist_tags(target))

  def more_artist_tags_on_source?(%{image: image, duplicate_of_image: target}),
    do: proper_subset?(artist_tags(target), artist_tags(image))

  def same_rating_tags?(%{image: image, duplicate_of_image: target}),
    do: MapSet.equal?(rating_tags(image), rating_tags(target))

  def target_is_edit?(%{duplicate_of_image: target}), do: edit?(target)
  def source_is_edit?(%{image: image}), do: edit?(image)

  def both_are_edits?(%{image: image, duplicate_of_image: target}),
    do: edit?(image) and edit?(target)

  def target_is_alternate_version?(%{duplicate_of_image: target}),
    do: alternate_version?(target)

  def source_is_alternate_version?(%{image: image}), do: alternate_version?(image)

  def both_are_alternate_versions?(%{image: image, duplicate_of_image: target}),
    do: alternate_version?(image) and alternate_version?(target)

  def mergeable?(%{image: image, duplicate_of_image: target} = report) do
    same_rating_tags?(report) and not image.hidden_from_users and
      not target.hidden_from_users and image.approved and target.approved
  end

  def source_approved?(%{image: image}), do: image.approved
  def target_approved?(%{duplicate_of_image: image}), do: image.approved

  defp format_index(mime_type) do
    Enum.find_index(@formats_order, &(mime_type == &1)) || length(@formats_order) - 1
  end

  defp artist_tags(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.namespace == "artist"))
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp rating_tags(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.category == "rating"))
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp edit?(%{tags: tags}), do: Enum.any?(tags, &(&1.name == "edit"))

  defp alternate_version?(%{tags: tags}),
    do: Enum.any?(tags, &(&1.name == "alternate version"))

  defp proper_subset?(first, second),
    do: MapSet.subset?(first, second) and not MapSet.equal?(first, second)
end
