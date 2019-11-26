defmodule Philomena.Processors.Svg do
  alias Philomena.Processors.Svg

  defstruct [:file, :preview]

  def new(_analysis, file) do
    %Svg{file: file, preview: nil}
  end

  # FIXME
  def strip(processor) do
    {processor, processor.file}
  end

  def preview(processor) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("inkscape", [processor.file, "--export-png", preview])
    
    processor = %{processor | preview: preview}

    {processor, preview}
  end

  def optimize(processor) do
    {processor, processor.file}
  end

  def scale(processor, {width, height}) do
    scaled = Briefly.create!(extname: ".png")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.preview, "-vf", scale_filter, scaled])
    {_output, 0} =
      System.cmd("optipng", ["-i0", "-o1", scaled])

    {processor, scaled}
  end
end