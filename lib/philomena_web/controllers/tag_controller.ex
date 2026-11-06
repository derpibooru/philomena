defmodule PhilomenaWeb.TagController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Tags

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    pagination = Map.put(conn.assigns.pagination, :page_size, 250)

    case Tags.query_tags(conn.assigns.actor, %{query: params["tq"] || "*"}, pagination) do
      {:ok, tags, _changeset} ->
        render(conn, "index.html", title: "Tags", tags: tags)

      {:error, %Ecto.Changeset{} = changeset} ->
        {message, _options} = Keyword.fetch!(changeset.errors, :query)
        render(conn, "index.html", title: "Tags", tags: [], error: message)

      error ->
        error
    end
  end

  def show(conn, params) do
    case Tags.show_tag_page(conn.assigns.actor, ImageScope.search_scope(conn), params["id"]) do
      {:ok, page} ->
        tag = page.tag
        body = MarkdownRenderer.render_one(%{body: tag.description || ""}, conn)

        dnp_bodies =
          MarkdownRenderer.render_collection(
            Enum.map(tag.dnp_entries, &%{body: &1.conditions || ""}),
            conn
          )

        dnp_entries = Enum.zip(dnp_bodies, tag.dnp_entries)

        conn_params = Map.put(conn.params, "q", page.search_query)
        conn = Map.put(conn, :params, conn_params)

        render(
          conn,
          "show.html",
          tag: tag,
          tags: [{tag, body, dnp_entries}],
          search_query: page.search_query,
          interactions: page.interactions,
          images: page.images,
          layout_class: "layout--wide",
          title: "#{tag.name} - Tags"
        )

      {:aliased_to, tag} ->
        conn
        |> put_flash(
          :info,
          "This tag (\"#{tag.name}\") has been aliased into the tag \"#{tag.aliased_tag.name}\"."
        )
        |> redirect(to: ~p"/tags/#{tag.aliased_tag}")

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {tag, changeset}} <-
           Tags.edit_tag(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html", title: "Editing Tag", tag: tag, changeset: changeset)
    end
  end

  def update(conn, %{"id" => slug, "tag" => tag_params}) do
    case Tags.update_tag(conn.assigns.actor, slug, tag_params) do
      {:ok, tag} ->
        conn
        |> put_flash(:info, "Tag successfully updated.")
        |> redirect(to: ~p"/tags/#{tag}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", tag: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    case Tags.delete_tag(conn.assigns.actor, params["id"]) do
      {:ok, _tag} ->
        conn
        |> put_flash(:info, "Tag queued for deletion.")
        |> redirect(to: "/")

      {:error, %Ecto.Changeset{data: tag}} ->
        conn
        |> put_flash(:error, "Rating tags cannot be deleted.")
        |> redirect(to: ~p"/tags/#{tag}")

      error ->
        error
    end
  end
end
