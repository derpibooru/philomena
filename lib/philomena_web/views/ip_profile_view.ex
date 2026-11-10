defmodule PhilomenaWeb.IpProfileView do
  use PhilomenaWeb, :view

  alias PhilomenaQuery.IpMask

  @spec ipv6?(Postgrex.INET.t()) :: boolean()
  def ipv6?(ip) do
    tuple_size(ip.address) == 8
  end

  def to_ipv6_mask(ip) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)

    IpMask.parse_mask(ip, %{"mask" => "64"})
  end
end
