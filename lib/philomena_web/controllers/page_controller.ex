defmodule PhilomenaWeb.PageController do
  use PhilomenaWeb, :controller

  alias Philomena.StaticPages
  alias PhilomenaWeb.MarkdownRenderer

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, static_pages} <- StaticPages.list_pages(conn.assigns.actor) do
      render(conn, "index.html", title: "Pages", static_pages: static_pages)
    end
  end

  def show(conn, %{"id" => slug}) do
    with {:ok, static_page} <- StaticPages.show_page(conn.assigns.actor, slug) do
      rendered = MarkdownRenderer.render_unsafe(static_page.body, conn)

      render(conn, "show.html",
        title: static_page.title,
        static_page: static_page,
        rendered: rendered
      )
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- StaticPages.new_page(conn.assigns.actor) do
      render(conn, "new.html", title: "New Page", changeset: changeset)
    end
  end

  def create(conn, %{"static_page" => static_page_params}) do
    case StaticPages.create_page(conn.assigns.actor, static_page_params) do
      {:ok, static_page} ->
        conn
        |> put_flash(:info, "Static page successfully created.")
        |> redirect(to: ~p"/pages/#{static_page}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      error ->
        error
    end
  end

  def edit(conn, %{"id" => slug}) do
    with {:ok, {static_page, changeset}} <-
           StaticPages.edit_page(conn.assigns.actor, slug) do
      render(conn, "edit.html",
        title: "Editing Page",
        static_page: static_page,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"id" => slug, "static_page" => static_page_params}) do
    case StaticPages.update_page(conn.assigns.actor, slug, static_page_params) do
      {:ok, static_page} ->
        conn
        |> put_flash(:info, "Static page successfully updated.")
        |> redirect(to: ~p"/pages/#{static_page}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", static_page: changeset.data, changeset: changeset)

      error ->
        error
    end
  end
end
