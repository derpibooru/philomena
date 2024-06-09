defmodule PhilomenaQuery.IpMask do
  @moduledoc """
  Postgres IP masks.
  """

  @doc """
  Parse a netmask from a string parameter, producing an `m:Postgrex.INET` type suitable for use in
  a containment (<<=, <<, >>, >>=) query. Ignores invalid strings and passes the IP through on
  error. [Postgres documentation](https://www.postgresql.org/docs/current/functions-net.html)
  has more information on `inet` operations.

  > #### Info {: .info}
  >
  > Netmasks lower than /8 are clamped to a minimum of /8. Such low masks are unlikely to be
  > useful and this avoids producing very expensive masks to evaluate.

  ## Examples

      iex> parse_mask(%Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}, %{"mask" => "12"})
      %Postgrex.INET{address: {192, 160, 0, 0}, netmask: 12}

      iex> parse_mask(%Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}, %{"mask" => "4"})
      %Postgrex.INET{address: {192, 0, 0, 0}, netmask: 8}

      iex> parse_mask(%Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}, %{"mask" => "64"})
      %Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}

      iex> parse_mask(%Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}, %{"mask" => "e"})
      %Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}

      iex> parse_mask(%Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}, %{})
      %Postgrex.INET{address: {192, 168, 1, 1}, netmask: 32}

      iex> parse_mask(%Postgrex.INET{
      ...>  address: {0x2001, 0xab0, 0x33a8, 0xd6e2, 0x10e9, 0xac1b, 0x9b0f, 0x67bc},
      ...>  netmask: 128
      ...> }, %{"mask" => "64"})
      %Postgrex.INET{address: {8193, 2736, 13224, 55010, 0, 0, 0, 0}, netmask: 64}

  """
  @spec parse_mask(Postgrex.INET.t(), map()) :: Postgrex.INET.t()
  def parse_mask(ip, params)

  def parse_mask(ip, %{"mask" => mask}) when is_binary(mask) do
    case Integer.parse(mask) do
      {mask, _rest} ->
        mask = clamp_mask(ip.address, mask)
        address = apply_mask(ip.address, mask)

        %Postgrex.INET{address: address, netmask: mask}

      _ ->
        ip
    end
  end

  def parse_mask(ip, _params), do: ip

  defp clamp(n, min, _max) when n < min, do: min
  defp clamp(n, _min, max) when n > max, do: max
  defp clamp(n, _min, _max), do: n

  defp clamp_mask(ip, mask) do
    # Clamp mask length:
    # - low end 8 (too taxing to evaluate)
    # - high end address_bits (limit of address)
    case tuple_size(ip) do
      4 ->
        clamp(mask, 8, 32)

      8 ->
        clamp(mask, 8, 128)
    end
  end

  defp unit_length(ip) when tuple_size(ip) == 4, do: 8
  defp unit_length(ip) when tuple_size(ip) == 8, do: 16

  defp apply_mask(ip, mask) when is_tuple(ip) do
    # Determine whether elements are octets or hexadectets
    length = unit_length(ip)

    # 1. Convert tuple to list of octets/hexadectets
    # 2. Convert list to bitstring
    # 3. Perform truncation operation on bitstring
    # 4. Convert bitstring back to list of octets/hexadectets
    # 5. Convert list to tuple

    ip
    |> Tuple.to_list()
    |> list_to_bits(length)
    |> apply_mask(mask)
    |> bits_to_list(length)
    |> List.to_tuple()
  end

  defp apply_mask(ip, mask) when is_binary(ip) do
    # Truncate bit size of ip to mask length and zero-fill the remainder
    <<ip::bits-size(mask), 0::integer-size(bit_size(ip) - mask)>>
  end

  defp list_to_bits(list, unit_length) do
    for u <- list, into: <<>>, do: <<u::integer-size(unit_length)>>
  end

  defp bits_to_list(bits, unit_length) do
    for <<u::integer-size(unit_length) <- bits>>, do: u
  end
end
