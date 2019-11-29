defmodule Philomena.Processors.Png do
  alias Philomena.Intensities

  def process(analysis, file, versions) do
    dimensions = analysis.dimensions

    {:ok, intensities} = Intensities.file(file)

    scaled = Enum.flat_map(versions, &scale_if_smaller(file, dimensions, &1))

    %{
      intensities: intensities,
      thumbnails: scaled
    }
  end

  def post_process(_analysis, file) do
    %{replace_original: optimize(file)}
  end

  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(file)
    intensities
  end


  defp optimize(file) do
    optimized = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("optipng", ["-fix", "-i0", "-o2", "-quiet", "-clobber", file, "-out", optimized])
    
    optimized
  end

  defp scale_if_smaller(_file, _dimensions, {:full, _target_dim}) do
    [{:symlink_original, "full.png"}]
  end

  defp scale_if_smaller(file, {width, height}, {thumb_name, {target_width, target_height}}) do
    if width > target_width or height > target_height do
      scaled = scale(file, {target_width, target_height})

      [{:copy, scaled, "#{thumb_name}.png"}]
    else
      [{:symlink_original, "#{thumb_name}.png"}]
    end
  end

  defp scale(file, {width, height}) do
    scaled = Briefly.create!(extname: ".png")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-vf", scale_filter, scaled])
    {_output, 0} =
      System.cmd("optipng", ["-i0", "-o1", "-quiet", "-clobber", scaled])

    scaled
  end
end