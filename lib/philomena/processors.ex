defmodule Philomena.Processors do
  alias Philomena.Images.Image
  alias Philomena.ImageIntensities
  alias Philomena.Repo
  alias Philomena.Mime
  alias Philomena.Sha512
  alias Philomena.Servers.ImageProcessor

  @mimes %{
    "image/gif" => "image/gif",
    "image/jpeg" => "image/jpeg",
    "image/png" => "image/png",
    "image/svg+xml" => "image/svg+xml",
    "video/webm" => "video/webm",
    "image/svg" => "image/svg+xml",
    "audio/webm" => "video/webm"
  }

  @analyzers %{
    "image/gif" => Philomena.Analyzers.Gif,
    "image/jpeg" => Philomena.Analyzers.Jpeg,
    "image/png" => Philomena.Analyzers.Png,
    "image/svg+xml" => Philomena.Analyzers.Svg,
    "video/webm" => Philomena.Analyzers.Webm
  }

  @processors %{
    "image/gif" => Philomena.Processors.Gif,
    "image/jpeg" => Philomena.Processors.Jpeg,
    "image/png" => Philomena.Processors.Png,
    "image/svg+xml" => Philomena.Processors.Svg,
    "video/webm" => Philomena.Processors.Webm
  }

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

  def after_upload(image, params) do
    with upload when not is_nil(upload) <- params["image"],
         file <- upload.path,
         {:ok, mime} <- Mime.file(file),
         mime <- @mimes[mime],
         analyzer when not is_nil(analyzer) <- @analyzers[mime],
         analysis <- analyzer.analyze(file),
         changes <- analysis_to_changes(analysis, file, upload.filename)
    do
      image
      |> Image.image_changeset(changes)
    else
      _ ->
        image
        |> Image.image_changeset(%{})
    end
  end

  def after_insert(image) do
    file = image_file(image)
    dir = Path.dirname(file)
    File.mkdir_p!(dir)
    File.cp!(image.uploaded_image, file)
    ImageProcessor.cast(self(), image.id)
  end

  def process_image(image_id) do
    image = Repo.get!(Image, image_id)

    mime = image.image_mime_type
    file = image_file(image)
    analyzer = @analyzers[mime]
    analysis = analyzer.analyze(file)
    processor = @processors[mime]
    process = processor.process(analysis, file, @versions)

    apply_edit_script(image, process)
    sha512 = Sha512.file(file)
    changeset = Image.thumbnail_changeset(image, %{"image_sha512_hash" => sha512})
    image = Repo.update!(changeset)

    processor.post_process(analysis, file)
    sha512 = Sha512.file(file)
    changeset = Image.process_changeset(image, %{"image_sha512_hash" => sha512})
    Repo.update!(changeset)
  end

  defp apply_edit_script(image, changes) do
    for change <- changes do
      apply_change(image, change)
    end
  end

  defp apply_change(image, {:intensities, intensities}) do
    ImageIntensities.create_image_intensity(image, intensities)
  end

  defp apply_change(image, {:replace_original, new_file}) do
    file = image_file(image)

    File.cp(new_file, file)
    File.chmod(file, 0o755)
  end

  defp apply_change(image, {:thumbnails, thumbnails}) do
    thumb_dir = image_thumb_dir(image)

    for thumbnail <- thumbnails do
      apply_thumbnail(image, thumb_dir, thumbnail)
    end
  end

  defp apply_thumbnail(_image, thumb_dir, {:copy, new_file, destination}) do
    new_destination = Path.join([thumb_dir, destination])
    dir = Path.dirname(new_destination)

    File.mkdir_p!(dir)
    File.cp!(new_file, new_destination)
    File.chmod!(new_destination, 0o755)
  end

  defp apply_thumbnail(image, thumb_dir, {:symlink_original, destination}) do
    file = Path.absname(image_file(image))
    new_destination = Path.join([thumb_dir, destination])
    dir = Path.dirname(new_destination)

    File.mkdir_p!(dir)
    File.rm(new_destination)
    File.ln_s!(file, new_destination)
    File.chmod!(new_destination, 0o755)
  end

  defp analysis_to_changes(analysis, file, upload_name) do
    {width, height} = analysis.dimensions
    {:ok, %{size: size}} = File.stat(file)
    sha512 = Sha512.file(file)
    filename = build_filename(analysis.extension)

    %{
      "image" => filename,
      "image_name" => upload_name,
      "image_width" => width,
      "image_height" => height,
      "image_size" => size,
      "image_format" => analysis.extension,
      "image_mime_type" => analysis.mime_type,
      "image_aspect_ratio" => aspect_ratio(width, height),
      "image_orig_sha512_hash" => sha512,
      "image_sha512_hash" => sha512,
      "is_animated" => analysis.animated?,
      "uploaded_image" => file
    }
  end

  defp aspect_ratio(_, 0), do: 0.0
  defp aspect_ratio(w, h), do: w / h

  defp image_file(image) do
    Path.join([image_file_root(), image.image])
  end

  defp image_thumb_dir(image) do
    Path.join([image_thumbnail_root(), time_identifier(image.created_at), to_string(image.id)])
  end

  defp build_filename(extension) do
    [
      time_identifier(DateTime.utc_now()),
      "/",
      usec_identifier(),
      pid_identifier(),
      ".",
      extension
    ]
    |> Enum.join()
  end

  defp time_identifier(time) do
    Enum.join([time.year, time.month, time.day], "/")
  end

  defp usec_identifier do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> to_string()
  end

  defp pid_identifier do
    self()
    |> :erlang.pid_to_list()
    |> to_string()
    |> String.replace(~r/[^0-9]/, "")
  end

  defp image_file_root do
    Application.get_env(:philomena, :image_file_root)
  end

  defp image_thumbnail_root do
    image_file_root() <> "/thumbs"
  end
end