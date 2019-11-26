defmodule Philomena.Processors do
  # alias Philomena.Images.Image
  # alias Philomena.Repo
  alias Philomena.Sha512

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

  def analysis_to_changes(analysis, file, upload_name) do
    {width, height} = analysis.dimensions
    %{size: size} = File.stat(file)
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
      "uploaded_image" => file
    }
  end

  def after_upload(image) do
    File.cp(image.uploaded_image, Path.join([image_file_root(), image.image]))
  end

  defp aspect_ratio(_, 0), do: 0.0
  defp aspect_ratio(w, h), do: w / h

  defp build_filename(extension) do
    [
      time_identifier(),
      "/",
      usec_identifier(),
      pid_identifier(),
      ".",
      extension
    ]
    |> Enum.join()
  end

  defp time_identifier do
    now = DateTime.utc_now()

    Enum.join([now.year, now.month, now.day], "/")
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