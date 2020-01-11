defmodule Philomena.Intensities do
  @doc """
  Gets the corner intensities of the given image file.
  The image file must be in the PNG or JPEG format.
  """
  @spec file(String.t()) :: {:ok, map()} | :error
  def file(input) do
    System.cmd("image-intensities", [input])
    |> case do
      {output, 0} ->
        [nw, ne, sw, se] =
          output
          |> String.trim()
          |> String.split("\t")
          |> Enum.map(&String.to_float/1)

        {:ok, %{nw: nw, ne: ne, sw: sw, se: se}}

      _error ->
        :error
    end
  end
end
