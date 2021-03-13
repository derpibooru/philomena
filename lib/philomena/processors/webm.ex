defmodule Philomena.Processors.Webm do
  alias Philomena.Intensities
  import Bitwise

  def process(analysis, file, versions) do
    dimensions = analysis.dimensions
    duration = analysis.duration
    stripped = strip(file)
    preview = preview(duration, stripped)
    palette = gif_palette(stripped, duration)
    mp4 = scale_mp4_only(stripped, dimensions, dimensions)

    {:ok, intensities} = Intensities.file(preview)

    scaled =
      Enum.flat_map(versions, &scale_if_smaller(stripped, mp4, palette, duration, dimensions, &1))

    %{
      replace_original: stripped,
      intensities: intensities,
      thumbnails: scaled ++ [{:copy, preview, "rendered.png"}]
    }
  end

  def post_process(_analysis, _file), do: %{}

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

  defp scale_if_smaller(_file, mp4, _palette, _duration, _dimensions, {:full, _target_dim}) do
    [
      {:symlink_original, "full.webm"},
      {:copy, mp4, "full.mp4"}
    ]
  end

  defp scale_if_smaller(
         file,
         mp4,
         palette,
         duration,
         {width, height},
         {thumb_name, {target_width, target_height}}
       ) do
    {webm, mp4} =
      if width > target_width or height > target_height do
        scale_videos(file, {width, height}, {target_width, target_height})
      else
        {file, mp4}
      end

    cond do
      thumb_name in [:thumb, :thumb_small, :thumb_tiny] ->
        gif = scale_gif(file, palette, duration, {target_width, target_height})

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

  defp scale_videos(file, dimensions, target_dimensions) do
    {width, height} = box_dimensions(dimensions, target_dimensions)
    webm = Briefly.create!(extname: ".webm")
    mp4 = Briefly.create!(extname: ".mp4")
    scale_filter = "scale=w=#{width}:h=#{height}"

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
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
        scale_filter,
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
        scale_filter,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        mp4
      ])

    {webm, mp4}
  end

  defp scale_mp4_only(file, dimensions, target_dimensions) do
    {width, height} = box_dimensions(dimensions, target_dimensions)
    mp4 = Briefly.create!(extname: ".mp4")
    scale_filter = "scale=w=#{width}:h=#{height}"

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
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
        scale_filter,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        mp4
      ])

    mp4
  end

  defp scale_gif(file, palette, duration, {width, height}) do
    gif = Briefly.create!(extname: ".gif")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"
    palette_filter = "paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    rate_filter = rate_filter(duration)
    filter_graph = "[0:v]#{scale_filter},#{rate_filter}[x];[x][1:v]#{palette_filter}"

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
        "-r",
        "2",
        gif
      ])

    gif
  end

  defp gif_palette(file, duration) do
    palette = Briefly.create!(extname: ".png")
    palette_filter = "palettegen=stats_mode=diff"
    rate_filter = rate_filter(duration)
    filter_graph = "#{rate_filter},#{palette_filter}"

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-vf",
        filter_graph,
        palette
      ])

    palette
  end

  # x264 requires image dimensions to be a multiple of 2
  # -2 = ~1
  def box_dimensions({width, height}, {target_width, target_height}) do
    ratio = min(target_width / width, target_height / height)
    new_width = min(max(trunc(width * ratio) &&& -2, 2), target_width)
    new_height = min(max(trunc(height * ratio) &&& -2, 2), target_height)

    {new_width, new_height}
  end

  # Avoid division by zero
  def rate_filter(duration) when duration > 0.5, do: "fps=1/#{duration / 10},settb=1/2,setpts=N"
  def rate_filter(_duration), do: "setpts=N/TB/2"
end
