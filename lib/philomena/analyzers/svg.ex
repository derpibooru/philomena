defmodule Philomena.Analyzers.Svg do
  def analyze(file) do
    %{
      extension: "svg",
      mime_type: "image/svg+xml",
      animated?: false,
      duration: 0.0,
      dimensions: dimensions(file)
    }
  end

  # Force use of MSVG to prevent invoking inkscape
  defp dimensions(file) do
    System.cmd("identify", ["-format", "%W %H\n", "msvg:#{file}"])
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