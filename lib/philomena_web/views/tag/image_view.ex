defmodule PhilomenaWeb.Tag.ImageView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.TagView

  defp tag_image(tag),
    do: TagView.tag_image(tag)
end
