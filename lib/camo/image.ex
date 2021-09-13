defmodule Camo.Image do
  def image_url(input), do: Philomena.Native.camo_image_url(input)
end
