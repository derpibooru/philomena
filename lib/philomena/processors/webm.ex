defmodule Philomena.Processors.Webm do
  alias Philomena.Processors.Webm
  import Bitwise

  defstruct [:duration, :file]

  def new(analysis, file) do
    %Webm{duration: analysis.duration, file: file}
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
    {processor, processor.file}
  end

  def scale(processor, dimensions) do
    {width, height} = normalize_dimensions(dimensions)
    scaled = Briefly.create!(extname: ".webm")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.file, "-c:v", "libvpx", "-crf", "10", "-b:v", "5M", "-vf", scale_filter, scaled])

    {processor, scaled}
  end

  # Force dimensions to be a multiple of 2. This is required by the
  # libvpx and x264 encoders.
  defp normalize_dimensions({width, height}) do
    {width &&& (~~~1), height &&& (~~~1)}
  end
end