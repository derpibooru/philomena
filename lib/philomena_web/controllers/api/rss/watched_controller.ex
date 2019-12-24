defmodule PhilomenaWeb.Api.Rss.WatchedController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader

  def index(conn, _params) do
    {:ok, {images, _tags}} = ImageLoader.search_string(conn, "my:watched")

    render(conn, "index.rss", images: images)
  end
end
