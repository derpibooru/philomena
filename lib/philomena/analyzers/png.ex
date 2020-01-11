defmodule Philomena.Analyzers.Png do
  def analyze(file) do
    animated? = animated?(file)
    duration = duration(animated?, file)

    %{
      extension: "png",
      mime_type: "image/png",
      animated?: animated?,
      duration: duration,
      dimensions: dimensions(file)
    }
  end

  defp animated?(file) do
    System.cmd("ffprobe", [
      "-i",
      file,
      "-v",
      "quiet",
      "-show_entries",
      "stream=codec_name",
      "-of",
      "csv=p=0"
    ])
    |> case do
      {"apng\n", 0} ->
        true

      _other ->
        false
    end
  end

  # No tooling available for this yet.
  defp duration(_animated?, _file), do: 0.0

  defp dimensions(file) do
    System.cmd("identify", ["-format", "%W %H\n", file])
    |> case do
      {output, 0} ->
        [width, height] =
          output
          |> String.trim()
          |> String.split(" ")
          |> Enum.map(&String.to_integer/1)

        {width, height}

      _error ->
        {0, 0}
    end
  end
end
