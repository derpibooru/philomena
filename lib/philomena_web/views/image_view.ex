defmodule PhilomenaWeb.ImageView do
  use PhilomenaWeb, :view

  alias Philomena.Images.Image

  def thumb_url(image, show_hidden, name) do
    Image.thumb_url(image, show_hidden, name)
  end
end
