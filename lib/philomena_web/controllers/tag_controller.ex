defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.{Tags, Tags.Tag}
  alias Philomena.Textile.Renderer
  alias Philomena.Interactions
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.RecodeParameterPlug, [name: "id"] when action in [:show]

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
    user = conn.assigns.current_user

    tag =
      Tag
      |> where(slug: ^slug)
      |> preload([:aliases, :implied_tags, :implied_by_tags, :dnp_entries, public_links: :user])
      |> Repo.one()

    {images, _tags} =
      ImageLoader.query(conn, %{term: %{"namespaced_tags.name" => tag.name}})

    interactions =
      Interactions.user_interactions(images, user)

    body =
      Renderer.render_one(%{body: tag.description || ""}, conn)

    dnp_bodies =
      Renderer.render_collection(Enum.map(tag.dnp_entries, &%{body: &1.conditions || ""}), conn)

    dnp_entries =
      Enum.zip(dnp_bodies, tag.dnp_entries)

    search_query = escape_name(tag)
    params = Map.put(conn.params, "q", search_query)
    conn = Map.put(conn, :params, params)

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
