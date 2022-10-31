defmodule PhilomenaWeb.Api.Rss.WatchedController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Images.Image
  alias Philomena.Elasticsearch

  import Ecto.Query

  def index(conn, _params) do
    {:ok, {images, _tags}} = ImageLoader.search_string(conn, "my:watched")
    images = Elasticsearch.search_records(images, preload(Image, tags: :aliases))

    # NB: this is RSS, but using the RSS format causes Phoenix not to
    # escape HTML
    conn
    |> put_resp_header("content-type", "application/rss+xml")
    |> render("index.html", layout: false, images: images)
  end
end
