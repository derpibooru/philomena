defmodule PhilomenaWeb.PageController do
  use PhilomenaWeb, :controller

  alias Philomena.StaticPages.StaticPage
  alias Philomena.StaticPages
  alias PhilomenaWeb.MarkdownRenderer

  plug :load_and_authorize_resource, model: StaticPage, id_field: "slug"

  def index(conn, _params) do
    render(conn, "index.html", title: "Pages")
  end

  def show(conn, _params) do
    rendered = MarkdownRenderer.render_unsafe(conn.assigns.static_page.body, conn)
    render(conn, "show.html", title: conn.assigns.static_page.title, rendered: rendered)
  end

  def new(conn, _params) do
    changeset = StaticPages.change_static_page(%StaticPage{})
    render(conn, "new.html", title: "New Page", changeset: changeset)
  end

  def create(conn, %{"static_page" => static_page_params}) do
    case StaticPages.create_static_page(conn.assigns.current_user, static_page_params) do
      {:ok, %{static_page: static_page}} ->
        conn
        |> put_flash(:info, "Static page successfully created.")
        |> redirect(to: Routes.page_path(conn, :show, static_page))

      {:error, :static_page, changeset, _changes} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = StaticPages.change_static_page(conn.assigns.static_page)
    render(conn, "edit.html", title: "Editing Page", changeset: changeset)
  end

  def update(conn, %{"static_page" => static_page_params}) do
    case StaticPages.update_static_page(
           conn.assigns.static_page,
           conn.assigns.current_user,
           static_page_params
         ) do
      {:ok, %{static_page: static_page}} ->
        conn
        |> put_flash(:info, "Static page successfully updated.")
        |> redirect(to: Routes.page_path(conn, :show, static_page))

      {:error, :static_page, changeset, _changes} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end
end
