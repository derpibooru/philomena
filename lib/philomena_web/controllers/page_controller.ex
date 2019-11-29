defmodule PhilomenaWeb.PageController do
  use PhilomenaWeb, :controller

  alias Philomena.StaticPages.StaticPage

  plug :load_resource, model: StaticPage, id_field: "slug"

  def show(conn, _params) do
    render(conn, "show.html", static_page: conn.assigns.static_page)
  end
end
