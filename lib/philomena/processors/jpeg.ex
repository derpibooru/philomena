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

  
  defp strip(file) do
    stripped = Briefly.create!(extname: ".jpg")

    {_output, 0} =
      System.cmd("convert", [file, "-auto-orient", "-strip", stripped])

    stripped
  end

  defp optimize(file) do
    optimized = Briefly.create!(extname: ".jpg")

    {_output, 0} =
      System.cmd("jpegtran", ["-optimize", "-outfile", optimized, file])

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
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-vf", scale_filter, scaled])
    {_output, 0} =
      System.cmd("jpegtran", ["-optimize", "-outfile", scaled, scaled])

    scaled
  end
end