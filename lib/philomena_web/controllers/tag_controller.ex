defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  def index(conn, _params) do
    tags = Tags.list_tags()
    render(conn, "index.html", tags: tags)
  end

  def show(conn, %{"id" => id}) do
    tag = Tags.get_tag!(id)
    render(conn, "show.html", tag: tag)
  end
end
