defmodule Philomena.Processors.Svg do
  alias Philomena.Intensities

  def process(_analysis, file, versions) do
    preview = preview(file)

    {:ok, intensities} = Intensities.file(preview)

    scaled = Enum.flat_map(versions, &scale_if_smaller(file, preview, &1))

    %{
      intensities: intensities,
      thumbnails: scaled ++ [{:copy, preview, "rendered.png"}]
    }
  end

  def post_process(_analysis, _file), do: %{}

  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(preview(file))
    intensities
  end


  defp preview(file) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("safe-rsvg-convert", [file, preview])

    preview
  end

  defp scale_if_smaller(_file, preview, {:full, _target_dim}) do
    [{:symlink_original, "full.svg"}, {:copy, preview, "full.png"}]
  end

  defp scale_if_smaller(_file, preview, {thumb_name, {target_width, target_height}}) do
    scaled = scale(preview, {target_width, target_height})

    [{:copy, scaled, "#{thumb_name}.png"}]
  end

  defp scale(preview, {width, height}) do
    scaled = Briefly.create!(extname: ".png")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", preview, "-vf", scale_filter, scaled])
    {_output, 0} =
      System.cmd("optipng", ["-i0", "-o1", "-quiet", "-clobber", scaled])

    scaled
  end
end