defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Tags, Tags.Tag}
  import Ecto.Query

  def index(conn, params) do
    {:ok, query} = Tags.Query.compile(params["tq"] || "*")

    tags =
      Tag.search_records(
        %{
          query: query,
          size: 250,
          sort: [%{images: :desc}, %{name: :asc}]
        },
        %{conn.assigns.pagination | page_size: 250},
        Tag
      )

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
        conn.assigns.pagination,
        Image |> preload([:tags, :user])
      )

    render(conn, "show.html", tag: tag, images: images)
  end
end
