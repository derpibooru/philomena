defmodule Mix.Tasks.UploadToS3 do
  use Mix.Task

  alias Philomena.{
    Adverts.Advert,
    Badges.Badge,
    Images.Image,
    Tags.Tag,
    Users.User
  }

  alias Philomena.Images.Thumbnailer
  alias Philomena.Mime
  alias Philomena.Batch
  alias ExAws.S3
  import Ecto.Query

  @shortdoc "Dumps existing image files to S3 storage backend"
  @requirements ["app.start"]
  @impl Mix.Task
  def run([concurrency | args]) do
    {concurrency, _} = Integer.parse(concurrency)

    if Enum.member?(args, "--adverts") do
      file_root = Application.fetch_env!(:philomena, :advert_file_root)
      new_file_root = System.get_env("NEW_ADVERT_FILE_ROOT", "adverts")

      IO.puts "\nAdverts:"
      upload_typical(where(Advert, [a], not is_nil(a.image)), concurrency, file_root, new_file_root, "image")
    end

    if Enum.member?(args, "--avatars") do
      file_root = Application.fetch_env!(:philomena, :avatar_file_root)
      new_file_root = System.get_env("NEW_AVATAR_FILE_ROOT", "avatars")

      IO.puts "\nAvatars:"
      upload_typical(where(User, [u], not is_nil(u.avatar)), concurrency, file_root, new_file_root, "avatar")
    end

    if Enum.member?(args, "--badges") do
      file_root = Application.fetch_env!(:philomena, :badge_file_root)
      new_file_root = System.get_env("NEW_BADGE_FILE_ROOT", "badges")

      IO.puts "\nBadges:"
      upload_typical(where(Badge, [b], not is_nil(b.image)), concurrency, file_root, new_file_root, "image")
    end

    if Enum.member?(args, "--tags") do
      file_root = Application.fetch_env!(:philomena, :tag_file_root)
      new_file_root = System.get_env("NEW_TAG_FILE_ROOT", "tags")

      IO.puts "\nTags:"
      upload_typical(where(Tag, [t], not is_nil(t.image)), concurrency, file_root, new_file_root, "image")
    end

    if Enum.member?(args, "--images") do
      # Temporarily adjust the file root so that the thumbs are picked up
      file_root = Application.fetch_env!(:philomena, :image_file_root) <> "thumbs"
      Application.put_env(:philomena, :image_file_root, file_root)

      new_file_root = System.get_env("NEW_IMAGE_FILE_ROOT", "images")

      IO.puts "\nImages:"
      upload_images(where(Image, [i], not is_nil(i.image)), concurrency, file_root, new_file_root)
    end
  end

  defp upload_typical(queryable, batch_size, file_root, new_file_root, field_name) do
    Batch.record_batches(queryable, [batch_size: batch_size], fn models ->
      Task.async_stream(models, &upload_typical_model(&1, file_root, new_file_root, field_name))

      IO.write "\r#{hd(models).id}"
    end)
  end

  defp upload_typical_model(model, file_root, new_file_root, field_name) do
    path = Path.join(file_root, Map.fetch!(model, field_name))

    if File.exists?(path) do
      put_file(path, Path.join(new_file_root, field_name))
    end
  end

  defp upload_images(queryable, batch_size, file_root, new_file_root) do
    Batch.record_batches(queryable, [batch_size: batch_size], fn models ->
      Task.async_stream(models, &upload_image_model(&1, file_root, new_file_root))

      IO.write "\r#{hd(models).id}"
    end)
  end

  defp upload_image_model(model, file_root, new_file_root) do
    path_prefix = Thumbnailer.image_thumb_prefix(model)

    Thumbnailer.all_versions(model)
    |> Enum.map(fn version ->
      path = Path.join([file_root, path_prefix, version])
      new_path = Path.join([new_file_root, path_prefix, version])

      put_file(path, new_path)
    end)
  end

  defp put_file(path, uploaded_path) do
    mime = Mime.file(path)
    contents = File.read!(path)

    S3.put_object(bucket(), uploaded_path, contents, acl: :public_read, content_type: mime)
    |> ExAws.request!()
  end

  defp bucket do
    Application.fetch_env!(:philomena, :s3_bucket)
  end
end
