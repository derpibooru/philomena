defmodule Philomena.Sha512 do
  @spec file(String.t()) :: String.t()
  def file(file) do
    hash_ref = :crypto.hash_init(:sha512)

    File.stream!(file, [], 10_485_760)
    |> Enum.reduce(hash_ref, &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end
end
