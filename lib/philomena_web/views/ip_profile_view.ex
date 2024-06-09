defmodule PhilomenaWeb.IpProfileView do
  use PhilomenaWeb, :view

  @spec ipv6?(Postgrex.INET.t()) :: boolean()
  def ipv6?(ip) do
    tuple_size(ip.address) == 8
  end
end
