defmodule PhilomenaMedia.Processors.Png do
  @moduledoc false

  alias PhilomenaMedia.Intensities
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Processors.Processor
  alias PhilomenaMedia.Processors

  @behaviour Processor

  @spec versions(Processors.version_list()) :: [Processors.version_filename()]
  def versions(sizes) do
    Enum.map(sizes, fn {name, _} -> "#{name}.png" end)
  end

  @spec process(Result.t(), Path.t(), Processors.version_list()) :: Processors.edit_script()
  def process(analysis, file, versions) do
    animated? = analysis.animated?

    {:ok, intensities} = Intensities.file(file)

    scaled = Enum.flat_map(versions, &scale(file, animated?, &1))

    [
      intensities: intensities,
      thumbnails: scaled
    ]
  end

  @spec post_process(Result.t(), Path.t()) :: Processors.edit_script()
  def post_process(analysis, file) do
    if analysis.animated? do
      # libpng has trouble with animations, so skip optimization
      []
    else
      [replace_original: optimize(file)]
    end
  end

  @spec intensities(Result.t(), Path.t()) :: Intensities.t()
  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(file)
    intensities
  end

  # Sobelow misidentifies removing the .bak file
  # sobelow_skip ["Traversal.FileModule"]
  defp optimize(file) do
    optimized = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("optipng", ["-fix", "-i0", "-o2", "-quiet", "-clobber", file, "-out", optimized])

    # Remove useless .bak file
    File.rm(optimized <> ".bak")

    optimized
  end

  defp scale(file, animated?, {thumb_name, {width, height}}) do
    scaled = Briefly.create!(extname: ".png")

    scale_filter =
      "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease,format=rgb32"

    {_output, 0} =
      cond do
        animated? ->
          System.cmd("ffmpeg", [
            "-loglevel",
            "0",
            "-y",
            "-i",
            file,
            "-plays",
            "0",
            "-vf",
            scale_filter,
            "-f",
            "apng",
            scaled
          ])

        true ->
          System.cmd("ffmpeg", ["-loglevel", "0", "-y", "-i", file, "-vf", scale_filter, scaled])
      end

    System.cmd("optipng", ["-i0", "-o1", "-quiet", "-clobber", scaled])

    [{:copy, scaled, "#{thumb_name}.png"}]
  end
end
