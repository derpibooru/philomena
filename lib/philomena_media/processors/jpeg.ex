defmodule PhilomenaMedia.Processors.Jpeg do
  @moduledoc false

  alias PhilomenaMedia.Intensities
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Remote
  alias PhilomenaMedia.Processors.Processor
  alias PhilomenaMedia.Strip
  alias PhilomenaMedia.Processors

  @behaviour Processor

  @exit_success 0
  @exit_warning 2

  @spec versions(Processors.version_list()) :: [Processors.version_filename()]
  def versions(sizes) do
    Enum.map(sizes, fn {name, _} -> "#{name}.jpg" end)
  end

  @spec process(Result.t(), Path.t(), Processors.version_list()) :: Processors.edit_script()
  def process(_analysis, file, versions) do
    source = file |> strip() |> optimize()

    {:ok, intensities} = Intensities.file(source)

    scaled = Enum.flat_map(versions, &scale(source, &1))

    replacement = if source != file, do: [replace_original: source], else: []

    replacement ++ [intensities: intensities, thumbnails: scaled]
  end

  @spec post_process(Result.t(), Path.t()) :: Processors.edit_script()
  def post_process(_analysis, _file), do: []

  @spec intensities(Result.t(), Path.t()) :: Intensities.t()
  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(file)
    intensities
  end

  defp strip(file) do
    # ImageMagick always reencodes the image, resulting in quality loss, so
    # be more clever
    if Strip.requires_strip?(file) do
      # Transcode: normalize orientation, ICC profile and strip metadata
      Strip.strip(file, ".jpg")
    else
      # Transmux only: Strip EXIF without touching pixel data
      stripped = Briefly.create!(extname: ".jpg")
      validate_return(Remote.cmd("jpegtran", ["-copy", "none", "-outfile", stripped, file]))
      stripped
    end
  end

  defp optimize(file) do
    optimized = Briefly.create!(extname: ".jpg")

    validate_return(Remote.cmd("jpegtran", ["-optimize", "-outfile", optimized, file]))

    optimized
  end

  defp scale(file, {thumb_name, {width, height}}) do
    scaled = Briefly.create!(extname: ".jpg")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      Remote.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-vf",
        scale_filter,
        "-q:v",
        "1",
        scaled
      ])

    {_output, 0} = Remote.cmd("jpegtran", ["-optimize", "-outfile", scaled, scaled])

    [{:copy, scaled, "#{thumb_name}.jpg"}]
  end

  defp validate_return({_output, ret}) when ret in [@exit_success, @exit_warning] do
    :ok
  end
end
