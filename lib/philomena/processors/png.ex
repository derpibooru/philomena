defmodule Philomena.Processors.Png do
  alias Philomena.Intensities

  def process(analysis, file, versions) do
    dimensions = analysis.dimensions
    animated? = analysis.animated?

    {:ok, intensities} = Intensities.file(file)

    scaled = Enum.flat_map(versions, &scale_if_smaller(file, animated?, dimensions, &1))

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

    # Remove useless .bak file
    File.rm(optimized <> ".bak")

    optimized
  end

  defp scale_if_smaller(_file, _animated?, _dimensions, {:full, _target_dim}) do
    [{:symlink_original, "full.png"}]
  end

  defp scale_if_smaller(
         file,
         animated?,
         {width, height},
         {thumb_name, {target_width, target_height}}
       ) do
    if width > target_width or height > target_height do
      scaled = scale(file, animated?, {target_width, target_height})

      [{:copy, scaled, "#{thumb_name}.png"}]
    else
      [{:symlink_original, "#{thumb_name}.png"}]
    end
  end

  defp scale(file, animated?, {width, height}) do
    scaled = Briefly.create!(extname: ".png")

    scale_filter =
      "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease,format=rgb32"

    {_output, 0} =
      cond do
        animated? ->
          System.cmd("ffmpeg", [
            "-loglevel",
            "0",
            "-y",
            "-i",
            file,
            "-plays",
            "0",
            "-vf",
            scale_filter,
            "-f",
            "apng",
            scaled
          ])

        true ->
          System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-vf", scale_filter, scaled])
      end

    System.cmd("optipng", ["-i0", "-o1", "-quiet", "-clobber", scaled])

    scaled
  end
end
