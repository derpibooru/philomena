defmodule Camo.Image do
  @doc """
  Convert a potentially untrusted external image URL into a trusted one
  loaded through a gocamo proxy (specified by the environment).
  """
  @spec image_url(String.t()) :: String.t()
  def image_url(input), do: Philomena.Native.camo_image_url(input)
end
