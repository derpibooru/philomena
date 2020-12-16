defmodule Philomena.Images.Thumbnailer do
  @moduledoc """
  Prevewing and thumbnailing logic for Images.
  """

  alias Philomena.DuplicateReports
  alias Philomena.ImageIntensities
  alias Philomena.Images.Image
  alias Philomena.Processors
  alias Philomena.Analyzers
  alias Philomena.Sha512
  alias Philomena.Repo

  @versions [
    thumb_tiny: {50, 50},
    thumb_small: {150, 150},
    thumb: {250, 250},
    small: {320, 240},
    medium: {800, 600},
    large: {1280, 1024},
    tall: {1024, 4096},
    full: nil
  ]

  def thumbnail_urls(image, hidden_key) do
    Path.join([image_thumb_dir(image), "*"])
    |> Path.wildcard()
    |> Enum.map(fn version_name ->
      Path.join([image_url_base(image, hidden_key), Path.basename(version_name)])
    end)
  end

  def generate_thumbnails(image_id) do
    image = Repo.get!(Image, image_id)
    file = image_file(image)
    {:ok, analysis} = Analyzers.analyze(file)

    apply_edit_script(image, Processors.process(analysis, file, @versions))
    generate_dupe_reports(image)
    recompute_meta(image, file, &Image.thumbnail_changeset/2)

    apply_edit_script(image, Processors.post_process(analysis, file))
    recompute_meta(image, file, &Image.process_changeset/2)
  end

  defp apply_edit_script(image, changes),
    do: Enum.map(changes, &apply_change(image, &1))

  defp apply_change(image, {:intensities, intensities}),
    do: ImageIntensities.create_image_intensity(image, intensities)

  defp apply_change(image, {:replace_original, new_file}),
    do: copy(new_file, image_file(image))

  defp apply_change(image, {:thumbnails, thumbnails}),
    do: Enum.map(thumbnails, &apply_thumbnail(image, image_thumb_dir(image), &1))

  defp apply_thumbnail(_image, thumb_dir, {:copy, new_file, destination}),
    do: copy(new_file, Path.join(thumb_dir, destination))

  defp apply_thumbnail(image, thumb_dir, {:symlink_original, destination}),
    do: symlink(image_file(image), Path.join(thumb_dir, destination))

  defp generate_dupe_reports(image) do
    if not image.duplication_checked do
      DuplicateReports.generate_reports(image)
    end
  end

  defp recompute_meta(image, file, changeset_fn) do
    {:ok, %{dimensions: {width, height}}} = Analyzers.analyze(file)

    image
    |> changeset_fn.(%{
      "image_sha512_hash" => Sha512.file(file),
      "image_size" => File.stat!(file).size,
      "image_width" => width,
      "image_height" => height
    })
    |> Repo.update!()
  end

  # Copy from source to destination, creating parent directories along
  # the way and setting the appropriate permission bits when necessary.
  defp copy(source, destination) do
    prepare_dir(destination)

    File.rm(destination)
    File.cp!(source, destination)

    set_perms(destination)
  end

  # Try to handle filesystems that don't support symlinks
  # by falling back to a copy.
  defp symlink(source, destination) do
    source = Path.absname(source)

    prepare_dir(destination)

    case File.ln_s(source, destination) do
      :ok ->
        set_perms(destination)

      _err ->
        copy(source, destination)
    end
  end

  # 0o644 = (S_IRUSR | S_IWUSR) | S_IRGRP | S_IROTH
  defp set_perms(destination),
    do: File.chmod(destination, 0o644)

  # Prepare the directory by creating it if it does not yet exist.
  defp prepare_dir(destination) do
    destination
    |> Path.dirname()
    |> File.mkdir_p!()
  end

  defp image_file(%Image{image: image}),
    do: Path.join(image_file_root(), image)

  defp image_thumb_dir(%Image{
         created_at: created_at,
         id: id,
         hidden_from_users: true,
         hidden_image_key: key
       }),
       do: Path.join([image_thumbnail_root(), time_identifier(created_at), "#{id}-#{key}"])

  defp image_thumb_dir(%Image{created_at: created_at, id: id}),
    do: Path.join([image_thumbnail_root(), time_identifier(created_at), to_string(id)])

  defp image_url_base(%Image{created_at: created_at, id: id}, nil),
    do: Path.join([image_url_root(), time_identifier(created_at), to_string(id)])

  defp image_url_base(%Image{created_at: created_at, id: id}, key),
    do: Path.join([image_url_root(), time_identifier(created_at), "#{id}-#{key}"])

  defp time_identifier(time),
    do: Enum.join([time.year, time.month, time.day], "/")

  defp image_file_root,
    do: Application.get_env(:philomena, :image_file_root)

  defp image_thumbnail_root,
    do: Application.get_env(:philomena, :image_file_root) <> "/thumbs"

  defp image_url_root,
    do: Application.get_env(:philomena, :image_url_root)
end
