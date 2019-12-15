defmodule PhilomenaWeb.Page.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.StaticPages.StaticPage
  alias Philomena.StaticPages.Version
  alias Philomena.Repo
  import Ecto.Query

  plug :load_resource, model: StaticPage, id_name: "page_id", id_field: "slug", persisted: true

  def index(conn, _params) do
    page = conn.assigns.static_page

    {versions, _last_body} =
      Version
      |> where(static_page_id: ^page.id)
      |> preload(:user)
      |> order_by(desc: :created_at)
      |> Repo.all()
      |> generate_differences(page.body)

    render(conn, "index.html", layout_class: "layout--wide", versions: versions)
  end

  defp generate_differences(pages, current_body) do
    Enum.map_reduce(pages, current_body, fn page, previous_body ->
      difference = List.myers_difference(split(page.body), split(previous_body))

      {%{page | difference: difference}, page.body}
    end)
  end

  defp split(nil), do: ""
  defp split(body), do: String.split(body, "\n")
end
