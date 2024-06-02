defmodule Philomena.Sha512 do
  @chunk_size 10_485_760

  @spec file(Path.t()) :: String.t()
  def file(path) do
    hash_ref = :crypto.hash_init(:sha512)

    path
    |> stream_file()
    |> Enum.reduce(hash_ref, &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  if Version.match?(System.version(), ">= 1.16.0") do
    # `stream!/2` was added in Elixir 1.16 to accept a shortened form,
    # where we only need to specify the size of each stream chunk
    defp stream_file(file) do
      File.stream!(file, @chunk_size)
    end
  else
    # Use legacy stream/3 for older Elixir versions
    defp stream_file(file) do
      File.stream!(file, [], @chunk_size)
    end
  end
end
