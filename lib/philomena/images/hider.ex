defmodule Philomena.Images.Hider do
  @moduledoc """
  Hiding logic for images.
  """

  alias Philomena.Images.Image

  def hide_thumbnails(image, key) do
    source = image_thumb_dir(image)
    target = image_thumb_dir(image, key)

    File.rm_rf(target)
    File.rename(source, target)
  end

  def unhide_thumbnails(image, key) do
    source = image_thumb_dir(image, key)
    target = image_thumb_dir(image)

    File.rm_rf(target)
    File.rename(source, target)
  end

  def destroy_thumbnails(image) do
    hidden = image_thumb_dir(image, image.hidden_image_key)
    normal = image_thumb_dir(image)

    File.rm_rf(hidden)
    File.rm_rf(normal)
  end

  def purge_cache(files) do
    {_out, 0} = System.cmd("purge-cache", [Jason.encode!(%{files: files})])

    :ok
  end

  # fixme: these are copied from the thumbnailer
  defp image_thumb_dir(%Image{created_at: created_at, id: id}),
    do: Path.join([image_thumbnail_root(), time_identifier(created_at), to_string(id)])

  defp image_thumb_dir(%Image{created_at: created_at, id: id}, key),
    do:
      Path.join([image_thumbnail_root(), time_identifier(created_at), to_string(id) <> "-" <> key])

  defp time_identifier(time),
    do: Enum.join([time.year, time.month, time.day], "/")

  defp image_thumbnail_root,
    do: Application.get_env(:philomena, :image_file_root) <> "/thumbs"
end
