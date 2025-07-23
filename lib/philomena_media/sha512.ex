defmodule PhilomenaMedia.Sha512 do
  @moduledoc """
  Streaming SHA-512 processor.
  """

  @chunk_size 10_485_760

  @doc """
  Generate the SHA2-512 hash of the file at the given path as a string.

  The file is processed in 10 MiB chunks.

  ## Example

      iex> Sha512.file("image.png")
      "97fd5243cd39e225f1478097acae71fbbff7f3027b24f0e6a8e06a0d7d3e6861cd05691d7470c76e7dfc4eb30459a906918d5ba0d144184fff02b8e34bd9ecf8"

  """
  @spec file(Path.t()) :: String.t()
  def file(path) do
    hash_ref = :crypto.hash_init(:sha512)

    path
    |> stream_file()
    |> Enum.reduce(hash_ref, &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp stream_file(file) do
    File.stream!(file, @chunk_size)
  end
end
