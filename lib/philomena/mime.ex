defmodule Philomena.Mime do
  @doc """
  Gets the MIME type of the given pathname.
  """
  @spec file(String.t()) :: {:ok, binary()} | :error
  def file(path) do
    System.cmd("file", ["-b", "--mime-type", path])
    |> case do
      {output, 0} ->
        {:ok, String.trim(output)}

      _error ->
        :error
    end
  end
end