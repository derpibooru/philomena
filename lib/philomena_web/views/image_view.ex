defmodule PhilomenaWeb.ImageView do
  use PhilomenaWeb, :view

  def thumb_url(image, show_hidden, name) do
    %{year: year, month: month, day: day} = image.created_at
    deleted = image.hidden_from_users
    format = image.image_format
    root = image_url_root()

    id_fragment =
      if deleted and show_hidden do
        "#{image.id}-#{image.hidden_image_Key}"
      else
        "#{image.id}"
      end

    "#{root}/#{year}/#{month}/#{day}/#{id_fragment}/#{name}.#{format}"
  end

  def pretty_url(image, _short, download) do
    %{year: year, month: month, day: day} = image.created_at
    root = image_url_root()

    view = if download, do: "download", else: "view"
    filename = "#{image.id}"
    format = image.image_format

    "#{root}/#{view}/#{year}/#{month}/#{day}/#{filename}.#{format}"
  end

  def image_url_root do
    Application.get_env(:philomena, :image_url_root)
  end
end
