defmodule Philomena.Analyzers.Gif do
  def analyze(file) do
    animated? = animated?(file)
    duration = duration(animated?, file)

    %{
      extension: "gif",
      mime_type: "image/gif",
      animated?: animated?,
      duration: duration,
      dimensions: dimensions(file)
    }
  end

  defp animated?(file) do
    System.cmd("identify", [file])
    |> case do
      {output, 0} ->
        len =
          output
          |> String.split("\n", parts: 2, trim: true)
          |> length()

        len > 1

      _error ->
        nil
    end
  end

  defp duration(false, _file), do: 0.0

  defp duration(true, file) do
    with {output, 0} <-
           System.cmd("ffprobe", [
             "-i",
             file,
             "-show_entries",
             "format=duration",
             "-v",
             "quiet",
             "-of",
             "csv=p=0"
           ]),
         {duration, _} <- Float.parse(output) do
      duration
    else
      _ ->
        0.0
    end
  end

  defp dimensions(file) do
    System.cmd("identify", ["-format", "%W %H\n", file])
    |> case do
      {output, 0} ->
        [width, height] =
          output
          |> String.split("\n", trim: true)
          |> hd()
          |> String.trim()
          |> String.split(" ")
          |> Enum.map(&String.to_integer/1)

        {width, height}

      _error ->
        {0, 0}
    end
  end
end
