defmodule Philomena.Processors.Jpeg do
  alias Philomena.Processors.Jpeg

  defstruct [:file]

  def new(_analysis, file) do
    %Jpeg{file: file}
  end

  def strip(processor) do
    stripped = Briefly.create!(extname: ".jpg")

    {_output, 0} =
      System.cmd("convert", [processor.file, "-auto-orient", "-strip", stripped])

    processor = %{processor | file: stripped}

    {processor, stripped}
  end

  def preview(processor) do
    {processor, processor.file}
  end

  def optimize(processor) do
    optimized = Briefly.create!(extname: ".jpg")

    {_output, 0} =
      System.cmd("jpegtran", ["-optimize", "-outfile", optimized, processor.file])
  end

  def scale(processor, {width, height}) do
    scaled = Briefly.create!(extname: ".jpg")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", ["-y", "-i", processor.file, "-vf", scale_filter, scaled])
    {_output, 0} =
      System.cmd("jpegtran", ["-optimize", "-outfile", scaled, scaled])

    {processor, scaled}
  end
end