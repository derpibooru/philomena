defmodule PhilomenaProxy.Camo do
  @moduledoc """
  Image proxying utilities.
  """

  @doc """
  Convert a potentially untrusted external image URL into a trusted one
  loaded through a gocamo proxy (specified by the environment).

  Configuration is read from environment variables at runtime by Philomena.

      config :philomena,
        camo_host: System.get_env("CAMO_HOST"),
        camo_key: System.get_env("CAMO_KEY"),

  ## Example

      iex> PhilomenaProxy.Camo.image_url("https://example.org/img/view/2024/1/1/1.png")
      "https://example.net/L5MqSmYq1ZEqiBGGvsvSDpILyJI/aHR0cHM6Ly9leGFtcGxlLm9yZy9pbWcvdmlldy8yMDI0LzEvMS8xLnBuZwo"

  """
  @spec image_url(String.t()) :: String.t()
  def image_url(input), do: Philomena.Native.camo_image_url(input)
end
