defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Tags}
  import Ecto.Query

  plug ImageFilter

  def index(conn, _params) do
    tags = Tags.list_tags()
    render(conn, "index.html", tags: tags)
  end

  def show(conn, %{"id" => slug}) do
    tag = Tags.get_tag!(slug)

    query = conn.assigns.compiled_filter

    images =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: query,
              must: %{term: %{"namespaced_tags.name": tag.name}}
            }
          },
          sort: %{created_at: :desc}
        },
        Image |> preload(:tags)
      )

    render(conn, "show.html", tag: tag, images: images)
  end
end
