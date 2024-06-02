defmodule PhilomenaMedia.Processors.Gif do
  @moduledoc false

  alias PhilomenaMedia.Intensities
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Processors.Processor
  alias PhilomenaMedia.Processors

  @behaviour Processor

  @spec versions(Processors.version_list()) :: [Processors.version_filename()]
  def versions(sizes) do
    sizes
    |> Enum.map(fn {name, _} -> "#{name}.gif" end)
    |> Kernel.++(["full.webm", "full.mp4", "rendered.png"])
  end

  @spec process(Result.t(), Path.t(), Processors.version_list()) :: Processors.edit_script()
  def process(analysis, file, versions) do
    duration = analysis.duration
    preview = preview(duration, file)
    palette = palette(file)

    {:ok, intensities} = Intensities.file(preview)

    scaled = Enum.flat_map(versions, &scale(palette, file, &1))
    videos = generate_videos(file)

    [
      intensities: intensities,
      thumbnails: scaled ++ videos ++ [{:copy, preview, "rendered.png"}]
    ]
  end

  @spec post_process(Result.t(), Path.t()) :: Processors.edit_script()
  def post_process(_analysis, file) do
    [replace_original: optimize(file)]
  end

  @spec intensities(Result.t(), Path.t()) :: Intensities.t()
  def intensities(analysis, file) do
    {:ok, intensities} = Intensities.file(preview(analysis.duration, file))
    intensities
  end

  defp optimize(file) do
    optimized = Briefly.create!(extname: ".gif")

    {_output, 0} = System.cmd("gifsicle", ["--careful", "-O2", file, "-o", optimized])

    optimized
  end

  defp preview(duration, file) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} = System.cmd("mediathumb", [file, to_string(duration / 2), preview])

    preview
  end

  defp palette(file) do
    palette = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-vf",
        "palettegen=stats_mode=diff",
        palette
      ])

    palette
  end

  defp scale(palette, file, {thumb_name, {width, height}}) do
    scaled = Briefly.create!(extname: ".gif")

    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    palette_filter =
      "paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle:alpha_threshold=255"

    filter_graph = "[0:v]#{scale_filter}[x];[x][1:v]#{palette_filter}"

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-i",
        palette,
        "-lavfi",
        filter_graph,
        scaled
      ])

    [{:copy, scaled, "#{thumb_name}.gif"}]
  end

  defp generate_videos(file) do
    webm = Briefly.create!(extname: ".webm")
    mp4 = Briefly.create!(extname: ".mp4")

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-pix_fmt",
        "yuv420p",
        "-c:v",
        "libvpx",
        "-deadline",
        "good",
        "-b:v",
        "5M",
        webm
      ])

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-vf",
        "scale=ceil(iw/2)*2:ceil(ih/2)*2",
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "main",
        "-crf",
        "18",
        "-b:v",
        "5M",
        mp4
      ])

    [
      {:copy, webm, "full.webm"},
      {:copy, mp4, "full.mp4"}
    ]
  end
end
