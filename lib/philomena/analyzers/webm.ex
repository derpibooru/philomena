defmodule Philomena.Analyzers.Webm do
  def analyze(file) do
    %{
      extension: "webm",
      mime_type: "video/webm",
      animated?: true,
      duration: duration(file),
      dimensions: dimensions(file)
    }
  end

  defp duration(file) do
    with {output, 0} <- System.cmd("ffprobe", ["-i", file, "-show_entries", "format=duration", "-v", "quiet", "-of", "csv=p=0"]),
         {duration, _} <- Float.parse(output)
    do
      duration
    else
      _ ->
        0.0
    end
  end

  defp dimensions(file) do
    System.cmd("ffprobe", ["-i", file, "-show_entries", "stream=width,height", "-v", "quiet", "-of", "csv=p=0"])
    |> case do
      {output, 0} ->
        [width, height] =
          output
          |> String.trim()
          |> String.split(",")
          |> Enum.map(&String.to_integer/1)

        {width, height}

      _error ->
        {0, 0}
    end
  end
end