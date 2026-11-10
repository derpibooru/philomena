defmodule PhilomenaWeb.FilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"fq" => fq}) do
    case Filters.query_filters(conn.assigns.actor, fq, conn.assigns.pagination) do
      {:ok, filters} ->
        render(conn, "index.html", title: "Filters", filters: filters)

      {:error, msg} ->
        render(conn, "index.html", title: "Filters", error: msg, filters: [])
    end
  end

  def index(conn, _params) do
    with {:ok, {my_filters, system_filters}} <-
           Filters.list_filters(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html",
        title: "Filters",
        my_filters: my_filters,
        system_filters: system_filters
      )
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, page} <- Filters.show_filter_page(conn.assigns.actor, id) do
      render(conn, "show.html",
        title: "Showing Filter",
        filter: page.filter,
        spoilered_tags: page.spoilered_tags,
        hidden_tags: page.hidden_tags
      )
    end
  end

  def new(conn, params) do
    with {:ok, changeset} <- Filters.new_filter(conn.assigns.actor, params["based_on"]) do
      render(conn, "new.html", title: "New Filter", changeset: changeset)
    end
  end

  def create(conn, %{"filter" => filter_params}) do
    case Filters.create_filter(conn.assigns.actor, filter_params) do
      {:ok, filter} ->
        conn
        |> put_flash(:info, "Filter created successfully.")
        |> redirect(to: ~p"/filters/#{filter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      error ->
        error
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, {filter, changeset}} <- Filters.edit_filter(conn.assigns.actor, id) do
      render(conn, "edit.html", title: "Editing Filter", filter: filter, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "filter" => filter_params}) do
    case Filters.update_filter(conn.assigns.actor, id, filter_params) do
      {:ok, filter} ->
        conn
        |> put_flash(:info, "Filter updated successfully.")
        |> redirect(to: ~p"/filters/#{filter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", filter: changeset.data, changeset: changeset)

      error ->
        error
    end
  end

  def delete(conn, %{"id" => id}) do
    case Filters.delete_filter(conn.assigns.actor, id) do
      {:ok, _filter} ->
        conn
        |> put_flash(:info, "Filter deleted successfully.")
        |> redirect(to: ~p"/filters")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Filter is still in use, not deleted.")
        |> redirect(to: ~p"/filters/#{changeset.data}")

      error ->
        error
    end
  end
end
