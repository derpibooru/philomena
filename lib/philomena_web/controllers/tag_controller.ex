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

    search_query = escape_name(tag)

    render(
      conn,
      "show.html",
      tag: tag,
      body: body,
      search_query: search_query,
      dnp_entries: dnp_entries,
      interactions: interactions,
      images: images,
      layout_class: "layout--wide"
    )
  end

  def escape_name(%{name: name}) do
    name =
      name
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
      |> String.downcase()

    cond do
      String.contains?(name, "(") or String.contains?(name, ")") ->
        # \ * ? " should be escaped, wrap in quotes so parser doesn't
        # choke on parens.
        name =
          name
          |> String.replace("\\", "\\\\")
          |> String.replace("*", "\\*")
          |> String.replace("?", "\\?")
          |> String.replace("\"", "\\\"")

        "\"#{name}\""

      true ->
        # \ * ? - ! " all must be escaped.
        name
        |> String.replace(~r/\A-/, "\\-")
        |> String.replace(~r/\A!/, "\\!")
        |> String.replace("\\", "\\\\")
        |> String.replace("*", "\\*")
        |> String.replace("?", "\\?")
        |> String.replace("\"", "\\\"")
    end
  end
end
