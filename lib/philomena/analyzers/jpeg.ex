defmodule Philomena.Analyzers.Jpeg do
  def analyze(file) do
    %{
      extension: "jpg",
      mime_type: "image/jpeg",
      animated?: false,
      duration: 0.0,
      dimensions: dimensions(file)
    }
  end

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