defmodule Philomena.Processors.Gif do
  alias Philomena.Processors.Gif

  defstruct [:duration, :file, :palette]

  def new(analysis, file) do
    %Gif{
      file: file,
      duration: analysis.duration,
      palette: nil
    }
  end

  def strip(processor) do
    {processor, processor.file}
  end

  def preview(processor) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.file, "-ss", to_string(processor.duration / 2), "-frames:v", "1", preview])

    {processor, preview}
  end

  def optimize(processor) do
    optimized = Briefly.create!(extname: ".gif")

    {_output, 0} =
      System.cmd("gifsicle", ["--careful", "-O2", processor.file, "-o", optimized])

    {processor, optimized}
  end

  def scale(processor, {width, height}) do
    processor = generate_palette(processor)
    scaled    = Briefly.create!(extname: ".gif")

    scale_filter   = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"
    palette_filter = "paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    filter_graph   = "#{scale_filter} [x]; [x][1:v] #{palette_filter}"

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.file, "-i", processor.palette, "-lavfi", filter_graph, scaled])

    {processor, scaled}
  end

  defp generate_palette(%{palette: nil} = processor) do
    palette = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.file, "-vf", "palettegen=stats_mode=diff", palette])

    %{processor | palette: palette}
  end
  defp generate_palette(processor), do: processor
end