defmodule Philomena.Processors.Svg do
  alias Philomena.Intensities

  def versions(sizes) do
    sizes
    |> Enum.map(fn {name, _} -> "#{name}.png" end)
    |> Kernel.++(["rendered.png", "full.png"])
  end

  def process(_analysis, file, versions) do
    preview = preview(file)

    {:ok, intensities} = Intensities.file(preview)

    scaled = Enum.flat_map(versions, &scale(preview, &1))
    full = [{:copy, preview, "full.png"}]

    %{
      intensities: intensities,
      thumbnails: scaled ++ full ++ [{:copy, preview, "rendered.png"}]
    }
  end

  def post_process(_analysis, _file), do: %{}

  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(preview(file))
    intensities
  end

  defp preview(file) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} = System.cmd("safe-rsvg-convert", [file, preview])

    preview
  end

  defp scale(preview, {thumb_name, {width, height}}) do
    scaled = Briefly.create!(extname: ".png")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", preview, "-vf", scale_filter, scaled])

    {_output, 0} = System.cmd("optipng", ["-i0", "-o1", "-quiet", "-clobber", scaled])

    [{:copy, scaled, "#{thumb_name}.png"}]
  end
end
