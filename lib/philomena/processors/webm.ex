defmodule Philomena.Processors.Webm do
  alias Philomena.Intensities
  import Bitwise

  def process(analysis, file, versions) do
    dimensions = analysis.dimensions
    duration = analysis.duration
    preview = preview(duration, file)
    palette = gif_palette(file)

    {:ok, intensities} = Intensities.file(preview)

    scaled = Enum.flat_map(versions, &scale_if_smaller(file, palette, dimensions, &1))

    %{
      intensities: intensities,
      thumbnails: scaled ++ [{:copy, preview, "rendered.png"}]
    }
  end

  def post_process(_analysis, _file), do: %{}

  defp preview(duration, file) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-ss", to_string(duration / 2), "-frames:v", "1", preview])

    preview
  end

  defp scale_if_smaller(palette, file, dimensions, {:full, _target_dim}) do
    {webm, mp4} = scale_videos(file, palette, dimensions)

    [
      {:copy, webm, "full.webm"},
      {:copy, mp4, "full.mp4"}
    ]
  end

  defp scale_if_smaller(palette, file, _dimensions, {thumb_name, {target_width, target_height}}) do
    {webm, mp4} = scale_videos(file, palette, {target_width, target_height})

    cond do
      thumb_name in [:thumb, :thumb_small, :thumb_tiny] ->
        gif = scale_gif(file, palette, {target_width, target_height})

        [
          {:copy, webm, "#{thumb_name}.webm"},
          {:copy, mp4, "#{thumb_name}.mp4"},
          {:copy, gif, "#{thumb_name}.gif"}
        ]

      true ->
        [
          {:copy, webm, "#{thumb_name}.webm"},
          {:copy, mp4, "#{thumb_name}.mp4"}
        ]
    end
  end

  defp scale_videos(file, _palette, dimensions) do
    {width, height} = normalize_dimensions(dimensions)
    webm = Briefly.create!(extname: ".webm")
    mp4  = Briefly.create!(extname: ".mp4")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-c:v", "libvpx", "-crf", "10", "-b:v", "5M", "-vf", scale_filter, webm])
    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-b:v", "5M", "-vf", scale_filter, mp4])

    {webm, mp4}
  end

  defp scale_gif(file, palette, {width, height}) do
    gif = Briefly.create!(extname: ".gif")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"
    palette_filter = "paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    filter_graph   = "#{scale_filter} [x]; [x][1:v] #{palette_filter}"

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-i", palette, "-lavfi", filter_graph, gif])
    
    gif
  end

  defp gif_palette(file) do
    palette = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-vf", "palettegen=stats_mode=diff", palette])

    palette
  end

  # Force dimensions to be a multiple of 2. This is required by the
  # libvpx and x264 encoders.
  defp normalize_dimensions({width, height}) do
    {width &&& (~~~1), height &&& (~~~1)}
  end
end