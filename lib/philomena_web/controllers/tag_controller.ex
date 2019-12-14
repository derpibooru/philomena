defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.{Tags, Tags.Tag}
  alias Philomena.Textile.Renderer
  alias Philomena.Interactions

  plug PhilomenaWeb.RecodeParameterPlug, [name: "id"] when action in [:show]
  plug PhilomenaWeb.CanaryMapPlug, update: :edit
  plug :load_and_authorize_resource, model: Tag, id_field: "slug", only: [:show, :edit, :update, :delete], preload: [:aliases, :aliased_tag, :implied_tags, :implied_by_tags, :dnp_entries, public_links: :user]
  plug :redirect_alias

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

  def show(conn, _params) do
    user = conn.assigns.current_user
    tag = conn.assigns.tag

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

  def edit(conn, _params) do
    changeset = Tags.change_tag(conn.assigns.tag)
    render(conn, "edit.html", changeset: changeset)
  end

  def update(conn, %{"tag" => tag_params}) do
    case Tags.update_tag(conn.assigns.tag, tag_params) do
      {:ok, tag} ->
        Tags.reindex_tag(tag)

        conn
        |> put_flash(:info, "Tag successfully updated.")
        |> redirect(to: Routes.tag_path(conn, :show, tag))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    spawn fn ->
      Tags.delete_tag(conn.assigns.tag)
    end

    conn
    |> put_flash(:info, "Tag scheduled for deletion.")
    |> redirect(to: "/")
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

  defp redirect_alias(conn, _opts) do
    case conn.assigns.tag do
      %{aliased_tag: nil} ->
        conn

      %{aliased_tag: tag} ->
        conn
        |> put_flash(:info, "This tag (`#{conn.assigns.tag.name}') has been aliased into the tag `#{tag.name}'.")
        |> redirect(to: Routes.tag_path(conn, :show, tag))
    end
  end
end
