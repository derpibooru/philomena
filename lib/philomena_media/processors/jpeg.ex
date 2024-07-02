defmodule PhilomenaMedia.Processors.Jpeg do
  @moduledoc false

  alias PhilomenaMedia.Intensities
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Processors.Processor
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
    stripped = optimize(strip(file))

    {:ok, intensities} = Intensities.file(stripped)

    scaled = Enum.flat_map(versions, &scale(stripped, &1))

    [
      replace_original: stripped,
      intensities: intensities,
      thumbnails: scaled
    ]
  end

  @spec post_process(Result.t(), Path.t()) :: Processors.edit_script()
  def post_process(_analysis, _file), do: []

  @spec intensities(Result.t(), Path.t()) :: Intensities.t()
  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(file)
    intensities
  end

  defp requires_lossy_transformation?(file) do
    with {output, 0} <-
           System.cmd("identify", ["-format", "%[orientation]\t%[profile:icc]", file]),
         [orientation, profile] <- String.split(output, "\t") do
      orientation not in ["Undefined", "TopLeft"] or profile != ""
    else
      _ ->
        true
    end
  end

  defp strip(file) do
    stripped = Briefly.create!(extname: ".jpg")

    # ImageMagick always reencodes the image, resulting in quality loss, so
    # be more clever
    case requires_lossy_transformation?(file) do
      true ->
        # Transcode: strip EXIF, embedded profile and reorient image
        {_output, 0} =
          System.cmd("convert", [
            file,
            "-profile",
            srgb_profile(),
            "-auto-orient",
            "-strip",
            stripped
          ])

      _ ->
        # Transmux only: Strip EXIF without touching orientation
        validate_return(System.cmd("jpegtran", ["-copy", "none", "-outfile", stripped, file]))
    end

    stripped
  end

  defp optimize(file) do
    optimized = Briefly.create!(extname: ".jpg")

    validate_return(System.cmd("jpegtran", ["-optimize", "-outfile", optimized, file]))

    optimized
  end

  defp scale(file, {thumb_name, {width, height}}) do
    scaled = Briefly.create!(extname: ".jpg")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", [
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

    {_output, 0} = System.cmd("jpegtran", ["-optimize", "-outfile", scaled, scaled])

    [{:copy, scaled, "#{thumb_name}.jpg"}]
  end

  defp srgb_profile do
    Path.join(File.cwd!(), "priv/icc/sRGB.icc")
  end

  defp validate_return({_output, ret}) when ret in [@exit_success, @exit_warning] do
    :ok
  end
end
