defmodule Philomena.Processors.Jpeg do
  alias Philomena.Intensities

  def process(analysis, file, versions) do
    dimensions = analysis.dimensions
    stripped = optimize(strip(file))

    {:ok, intensities} = Intensities.file(stripped)

    scaled = Enum.flat_map(versions, &scale_if_smaller(stripped, dimensions, &1))

    %{
      replace_original: stripped,
      intensities: intensities,
      thumbnails: scaled
    }
  end

  def post_process(_analysis, _file), do: %{}

  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(file)
    intensities
  end

  defp requires_lossy_transformation?(file) do
    with {output, 0} <-
           System.cmd("identify", ["-format", "%[orientation]\t%[profile:icc]", file]),
         [orientation, profile] <- String.split(output, "\t") do
      orientation != "Undefined" or profile != ""
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
        {_output, 0} = System.cmd("jpegtran", ["-copy", "none", "-outfile", stripped, file])
    end

    stripped
  end

  defp optimize(file) do
    optimized = Briefly.create!(extname: ".jpg")

    {_output, 0} = System.cmd("jpegtran", ["-optimize", "-outfile", optimized, file])

    optimized
  end

  defp scale_if_smaller(_file, _dimensions, {:full, _target_dim}) do
    [{:symlink_original, "full.jpg"}]
  end

  defp scale_if_smaller(file, {width, height}, {thumb_name, {target_width, target_height}}) do
    if width > target_width or height > target_height do
      scaled = scale(file, {target_width, target_height})

      [{:copy, scaled, "#{thumb_name}.jpg"}]
    else
      [{:symlink_original, "#{thumb_name}.jpg"}]
    end
  end

  defp scale(file, {width, height}) do
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

    scaled
  end

  defp srgb_profile do
    Path.join(File.cwd!(), "priv/icc/sRGB.icc")
  end
end
