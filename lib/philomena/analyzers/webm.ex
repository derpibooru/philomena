defmodule Philomena.Analyzers.Webm do
  def analyze(file) do
    stats = stats(file)

    %{
      extension: "webm",
      mime_type: "video/webm",
      animated?: true,
      duration: stats.duration,
      dimensions: stats.dimensions
    }
  end

  defp stats(file) do
    case System.cmd("mediastat", [file]) do
      {output, 0} ->
        [_size, _frames, width, height, num, den] =
          output
          |> String.trim()
          |> String.split(" ")
          |> Enum.map(&String.to_integer/1)

        %{dimensions: {width, height}, duration: num / den}

      _ ->
        %{dimensions: {0, 0}, duration: 0.0}
    end
  end
end
