defmodule PhilomenaMedia.GifPreview do
  @moduledoc """
  GIF preview generation for video files.
  """

  @type duration :: float()
  @type dimensions :: {pos_integer(), pos_integer()}

  @type num_images :: integer()
  @type target_framerate :: 1..50
  @type opts :: [
          num_images: num_images(),
          target_framerate: target_framerate()
        ]

  @doc """
  Generate a GIF preview of the given video input with evenly-spaced sample points.

  The input should have pre-computed duration `duration`. The `dimensions`
  are a `{target_width, target_height}` tuple.

  Depending on the input file, this may take a long time to process.

  Options:
  - `:target_framerate` - framerate of the output GIF, must be between 1 and 50.
    Default 2.
  - `:num_images` - number of images to sample from the video.
    Default is determined by the duration:
    * 90 or above: 20 images
    * 30 or above: 10 images
    * 1 or above: 5 images
    * otherwise: 2 images
  """
  @spec preview(Path.t(), Path.t(), duration(), dimensions(), opts()) :: :ok
  def preview(video, gif, duration, dimensions, opts \\ []) do
    target_framerate = Keyword.get(opts, :target_framerate, 2)

    num_images =
      Keyword.get_lazy(opts, :num_images, fn ->
        cond do
          duration >= 90 -> 20
          duration >= 30 -> 10
          duration >= 1 -> 5
          true -> 2
        end
      end)

    {_output, 0} =
      System.cmd(
        "ffmpeg",
        commands(video, gif, clamp(duration), dimensions, num_images, target_framerate)
      )

    :ok
  end

  @spec commands(Path.t(), Path.t(), duration(), dimensions(), num_images(), target_framerate()) ::
          [String.t()]
  defp commands(video, gif, duration, {target_width, target_height}, num_images, target_framerate) do
    # Compute range [0, num_images)
    image_range = 0..(num_images - 1)

    # Generate input list in the following form:
    #   -ss 0.0 -i input.webm
    input_arguments =
      Enum.flat_map(image_range, &["-ss", "#{&1 * duration / num_images}", "-i", video])

    # Generate graph in the following form:
    #   [0:v] trim=end_frame=1 [t0]; [1:v] trim=end_frame=1 [t1] ...
    trim_filters =
      Enum.map_join(image_range, ";", &"[#{&1}:v] trim=end_frame=1 [t#{&1}]")

    # Generate graph in the following form:
    #   [t0][t1]... concat=n=10 [concat]
    concat_input_pads =
      Enum.map_join(image_range, "", &"[t#{&1}]")

    concat_filter =
      "#{concat_input_pads} concat=n=#{num_images}, settb=1/#{target_framerate}, setpts=N [concat]"

    scale_filter =
      "[concat] scale=width=#{target_width}:height=#{target_height},setsar=1 [scale]"

    split_filter = "[scale] split [s0][s1]"

    palettegen_filter =
      "[s0] palettegen=stats_mode=single:max_colors=255:reserve_transparent=1 [palettegen]"

    paletteuse_filter =
      "[s1][palettegen] paletteuse=dither=bayer:bayer_scale=5:new=1:alpha_threshold=255"

    filter_graph =
      [
        trim_filters,
        concat_filter,
        scale_filter,
        split_filter,
        palettegen_filter,
        paletteuse_filter
      ]
      |> Enum.join(";")

    # Delay in centiseconds - otherwise it will be computed incorrectly
    final_delay = 100.0 / target_framerate

    ["-loglevel", "0", "-y"]
    |> Kernel.++(input_arguments)
    |> Kernel.++(["-lavfi", filter_graph])
    |> Kernel.++(["-f", "gif", "-final_delay", "#{final_delay}", gif])
  end

  defp clamp(duration) when duration <= 0, do: 1.0
  defp clamp(duration), do: duration
end
