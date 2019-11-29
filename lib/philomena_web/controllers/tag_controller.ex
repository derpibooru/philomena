defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Tags, Tags.Tag}
  alias Philomena.Textile.Renderer
  alias Philomena.Interactions
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, params) do
    query_string = params["tq"] || "*"

    with {:ok, query} <- Tags.Query.compile(query_string) do
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
    else
      {:error, msg} ->
        render(conn, "index.html", tags: [], error: msg)
    end
  end

  def show(conn, %{"id" => slug}) do
    tag =
      Tag
      |> where(slug: ^slug)
      |> preload([:aliases, :implied_tags, :implied_by_tags, :dnp_entries, public_links: :user])
      |> Repo.one()

    query = conn.assigns.compiled_filter
    user = conn.assigns.current_user

    images =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: [query, %{term: %{hidden_from_users: true}}],
              must: %{term: %{"namespaced_tags.name": tag.name}}
            }
          },
          sort: %{created_at: :desc}
        },
        conn.assigns.pagination,
        Image |> preload([:tags, :user])
      )

    interactions =
      Interactions.user_interactions(images, user)

    body =
      Renderer.render_one(%{body: tag.description || ""})

    dnp_bodies =
      Renderer.render_collection(Enum.map(tag.dnp_entries, &%{body: &1.conditions || ""}))

    dnp_entries =
      Enum.zip(dnp_bodies, tag.dnp_entries)

    render(conn, "show.html", tag: tag, body: body, dnp_entries: dnp_entries, interactions: interactions, images: images, layout_class: "layout--wide")
  end
end
