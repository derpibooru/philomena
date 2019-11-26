defmodule Philomena.Processors.Png do
  alias Philomena.Processors.Png

  defstruct [:file]

  def new(_analysis, file) do
    %Png{file: file}
  end

  def strip(processor) do
    {processor, processor.file}
  end

  def preview(processor) do
    {processor, processor.file}
  end

  def optimize(processor) do
    optimized = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("optipng", ["-fix", "-i0", "-o2", processor.file, "-out", optimized])
    
    {processor, optimized}
  end

  def scale(processor, {width, height}) do
    scaled = Briefly.create!(extname: ".png")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.file, "-vf", scale_filter, scaled])
    {_output, 0} =
      System.cmd("optipng", ["-i0", "-o1", scaled])

    {processor, scaled}
  end
end