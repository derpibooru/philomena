defmodule PhilomenaMedia.Processors.Webm do
  @moduledoc false

  alias PhilomenaMedia.Intensities
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.GifPreview
  alias PhilomenaMedia.Processors.Processor
  alias PhilomenaMedia.Processors
  import Bitwise

  @behaviour Processor

  @spec versions(Processors.version_list()) :: [Processors.version_filename()]
  def versions(sizes) do
    webm_versions = Enum.map(sizes, fn {name, _} -> "#{name}.webm" end)
    mp4_versions = Enum.map(sizes, fn {name, _} -> "#{name}.mp4" end)

    gif_versions =
      sizes
      |> Enum.filter(fn {name, _} -> name in [:thumb_tiny, :thumb_small, :thumb] end)
      |> Enum.map(fn {name, _} -> "#{name}.gif" end)

    ["full.mp4", "rendered.png"] ++ webm_versions ++ mp4_versions ++ gif_versions
  end

  @spec process(Result.t(), Path.t(), Processors.version_list()) :: Processors.edit_script()
  def process(analysis, file, versions) do
    dimensions = analysis.dimensions
    duration = analysis.duration
    stripped = strip(file)
    preview = preview(duration, stripped)
    decoder = select_decoder(file)
    mp4 = scale_mp4_only(decoder, stripped, dimensions, dimensions)

    {:ok, intensities} = Intensities.file(preview)

    scaled = Enum.flat_map(versions, &scale(decoder, stripped, duration, dimensions, &1))
    mp4 = [{:copy, mp4, "full.mp4"}]

    [
      replace_original: stripped,
      intensities: intensities,
      thumbnails: scaled ++ mp4 ++ [{:copy, preview, "rendered.png"}]
    ]
  end

  @spec post_process(Result.t(), Path.t()) :: Processors.edit_script()
  def post_process(_analysis, _file), do: []

  @spec intensities(Result.t(), Path.t()) :: Intensities.t()
  def intensities(analysis, file) do
    {:ok, intensities} = Intensities.file(preview(analysis.duration, file))
    intensities
  end

  defp preview(duration, file) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} = System.cmd("mediathumb", [file, to_string(duration / 2), preview])

    preview
  end

  defp strip(file) do
    stripped = Briefly.create!(extname: ".webm")

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-map_metadata",
        "-1",
        "-c",
        "copy",
        "-map",
        "0",
        stripped
      ])

    stripped
  end

  defp scale(decoder, file, duration, dimensions, {thumb_name, target_dimensions}) do
    {webm, mp4} = scale_videos(decoder, file, dimensions, target_dimensions)

    if thumb_name in [:thumb, :thumb_small, :thumb_tiny] do
      gif = scale_gif(decoder, file, duration, dimensions, target_dimensions)

      [
        {:copy, webm, "#{thumb_name}.webm"},
        {:copy, mp4, "#{thumb_name}.mp4"},
        {:copy, gif, "#{thumb_name}.gif"}
      ]
    else
      [
        {:copy, webm, "#{thumb_name}.webm"},
        {:copy, mp4, "#{thumb_name}.mp4"}
      ]
    end
  end

  defp scale_videos(decoder, file, dimensions, target_dimensions) do
    filter = scale_filter(dimensions, target_dimensions)
    webm = Briefly.create!(extname: ".webm")
    mp4 = Briefly.create!(extname: ".mp4")

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-c:v",
        decoder,
        "-i",
        file,
        "-c:v",
        "libvpx",
        "-deadline",
        "good",
        "-cpu-used",
        "5",
        "-auto-alt-ref",
        "0",
        "-qmin",
        "15",
        "-qmax",
        "35",
        "-crf",
        "31",
        "-vf",
        filter,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        "-slices",
        "8",
        webm,
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "main",
        "-preset",
        "medium",
        "-crf",
        "18",
        "-b:v",
        "5M",
        "-vf",
        filter,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        mp4
      ])

    {webm, mp4}
  end

  defp scale_mp4_only(decoder, file, dimensions, target_dimensions) do
    filter = scale_filter(dimensions, target_dimensions)
    mp4 = Briefly.create!(extname: ".mp4")

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-c:v",
        decoder,
        "-i",
        file,
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "main",
        "-preset",
        "medium",
        "-crf",
        "18",
        "-b:v",
        "5M",
        "-vf",
        filter,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        mp4
      ])

    mp4
  end

  defp scale_gif(decoder, file, duration, dimensions, target_dimensions) do
    {width, height} = box_dimensions(dimensions, target_dimensions)
    gif = Briefly.create!(extname: ".gif")

    GifPreview.preview(decoder, file, gif, duration, {width, height})

    gif
  end

  defp select_decoder(file) do
    {output, 0} =
      System.cmd("ffprobe", [
        "-loglevel",
        "0",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_name",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        "-i",
        file
      ])

    # Mediatools verifies that we only have one video stream and that it is
    # one of the supported formats, so the following is safe to do:
    case output do
      "vp8\n" -> "libvpx"
      "vp9\n" -> "libvpx-vp9"
      "av1\n" -> "av1"
    end
  end

  defp scale_filter(dimensions, target_dimensions) do
    {width, height} = box_dimensions(dimensions, target_dimensions)
    "scale=w=#{width}:h=#{height},setsar=1"
  end

  # x264 requires image dimensions to be a multiple of 2
  # -2 = ~1
  defp box_dimensions({width, height}, {target_width, target_height}) do
    ratio = min(target_width / width, target_height / height)
    new_width = min(max(trunc(width * ratio) &&& -2, 2), target_width)
    new_height = min(max(trunc(height * ratio) &&& -2, 2), target_height)

    {new_width, new_height}
  end
end
