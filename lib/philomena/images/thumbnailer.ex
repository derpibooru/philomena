defmodule Philomena.Images.Thumbnailer do
  @moduledoc """
  Prevewing and thumbnailing logic for Images.
  """

  alias PhilomenaMedia.Processors
  alias PhilomenaMedia.Analyzers
  alias PhilomenaMedia.Uploader
  alias PhilomenaMedia.Objects
  alias PhilomenaMedia.Sha512

  alias Philomena.DuplicateReports
  alias Philomena.ImageIntensities
  alias Philomena.ImagePurgeWorker
  alias Philomena.Images.Image
  alias Philomena.Repo

  require Logger

  @versions [
    thumb_tiny: {50, 50},
    thumb_small: {150, 150},
    thumb: {250, 250},
    small: {320, 240},
    medium: {800, 600},
    large: {1280, 1024},
    tall: {1024, 4096}
  ]

  def thumbnail_versions do
    @versions
  end

  # A list of version sizes that should be generated for the image,
  # based on its dimensions. The processor can generate a list of paths.
  def generated_sizes(%{image_width: image_width, image_height: image_height}) do
    Enum.filter(@versions, fn
      {_name, {width, height}} -> image_width > width or image_height > height
    end)
  end

  def thumbnail_urls(image, hidden_key) do
    image
    |> all_versions()
    |> Enum.map(fn name ->
      Path.join(image_url_base(image, hidden_key), name)
    end)
  end

  def hide_thumbnails(image, key) do
    moved_files = all_versions(image)

    source_prefix = visible_image_thumb_prefix(image)
    target_prefix = hidden_image_thumb_prefix(image, key)

    bulk_rename(moved_files, source_prefix, target_prefix)
  end

  def unhide_thumbnails(image, key) do
    moved_files = all_versions(image)

    source_prefix = hidden_image_thumb_prefix(image, key)
    target_prefix = visible_image_thumb_prefix(image)

    bulk_rename(moved_files, source_prefix, target_prefix)
  end

  def destroy_thumbnails(image) do
    affected_files = all_versions(image)

    hidden_prefix = hidden_image_thumb_prefix(image, image.hidden_image_key)
    visible_prefix = visible_image_thumb_prefix(image)

    bulk_delete(affected_files, hidden_prefix)
    bulk_delete(affected_files, visible_prefix)
  end

  def generate_thumbnails(image_id) do
    image = Repo.get!(Image, image_id)

    Logger.debug("Generating thumbnails for the image #{image.id}")

    file = download_image_file(image)
    {:ok, analysis} = Analyzers.analyze_path(file)

    file =
      apply_edit_script(image, file, Processors.process(analysis, file, generated_sizes(image)))

    generate_dupe_reports(image)
    recompute_meta(image, file, &Image.thumbnail_changeset/2)

    file = apply_edit_script(image, file, Processors.post_process(analysis, file))
    recompute_meta(image, file, &Image.process_changeset/2)
  end

  defp apply_edit_script(image, file, changes) do
    Enum.reduce(changes, file, fn change, existing_file ->
      apply_change(image, change)

      case change do
        {:replace_original, new_file} ->
          new_file

        _ ->
          existing_file
      end
    end)
  end

  defp apply_change(image, {:intensities, intensities}),
    do: ImageIntensities.create_image_intensity(image, intensities)

  defp apply_change(image, {:replace_original, new_file}) do
    full = "full.#{image.image_format}"
    upload_file(image, new_file, full)

    Exq.enqueue(Exq, "indexing", ImagePurgeWorker, [
      Path.join(image_url_base(image, nil), full)
    ])
  end

  defp apply_change(image, {:thumbnails, thumbnails}),
    do: Enum.map(thumbnails, &apply_thumbnail(image, &1))

  defp apply_thumbnail(image, {:copy, new_file, destination}),
    do: upload_file(image, new_file, destination)

  defp generate_dupe_reports(image) do
    if not image.duplication_checked do
      DuplicateReports.generate_reports(image)
    end
  end

  defp recompute_meta(image, file, changeset_fn) do
    {:ok, %{dimensions: {width, height}}} = Analyzers.analyze_path(file)

    image
    |> changeset_fn.(%{
      "image_sha512_hash" => Sha512.file(file),
      "image_size" => File.stat!(file).size,
      "image_width" => width,
      "image_height" => height,
      "image_aspect_ratio" => width / height
    })
    |> Repo.update!()
  end

  defp download_image_file(image) do
    tempfile = Briefly.create!(extname: ".#{image.image_format}")
    path = Path.join(image_thumb_prefix(image), "full.#{image.image_format}")

    Objects.download_file(path, tempfile)

    tempfile
  end

  def upload_file(image, file, version_name) do
    path = Path.join(image_thumb_prefix(image), version_name)

    Uploader.persist_file(path, file)
  end

  defp bulk_rename(file_names, source_prefix, target_prefix) do
    file_names
    |> Task.async_stream(
      fn name ->
        source = Path.join(source_prefix, name)
        target = Path.join(target_prefix, name)
        Objects.copy(source, target)

        name
      end,
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, name} -> name end)
    |> bulk_delete(source_prefix)
  end

  defp bulk_delete(file_names, prefix) do
    file_names
    |> Enum.map(&Path.join(prefix, &1))
    |> Objects.delete_multiple()
  end

  def all_versions(image) do
    generated = Processors.versions(image.image_mime_type, generated_sizes(image))
    full = ["full.#{image.image_format}"]

    generated ++ full
  end

  # This method wraps the following two for code that doesn't care
  # and just wants the files (most code should take this path)

  def image_thumb_prefix(%{hidden_from_users: true} = image),
    do: hidden_image_thumb_prefix(image, image.hidden_image_key)

  def image_thumb_prefix(image),
    do: visible_image_thumb_prefix(image)

  # These methods handle the actual distinction between the two

  defp hidden_image_thumb_prefix(%Image{created_at: created_at, id: id}, key),
    do: Path.join([image_file_root(), time_identifier(created_at), "#{id}-#{key}"])

  defp visible_image_thumb_prefix(%Image{created_at: created_at, id: id}),
    do: Path.join([image_file_root(), time_identifier(created_at), to_string(id)])

  defp image_url_base(%Image{created_at: created_at, id: id}, nil),
    do: Path.join([image_url_root(), time_identifier(created_at), to_string(id)])

  defp image_url_base(%Image{created_at: created_at, id: id}, key),
    do: Path.join([image_url_root(), time_identifier(created_at), "#{id}-#{key}"])

  defp time_identifier(time),
    do: Enum.join([time.year, time.month, time.day], "/")

  defp image_file_root,
    do: Application.fetch_env!(:philomena, :image_file_root)

  defp image_url_root,
    do: Application.fetch_env!(:philomena, :image_url_root)
end
