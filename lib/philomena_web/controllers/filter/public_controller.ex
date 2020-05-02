defmodule PhilomenaWeb.Filter.PublicController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters
  alias Philomena.Filters.Filter

  plug PhilomenaWeb.CanaryMapPlug, create: :edit
  plug :load_and_authorize_resource, model: Filter, id_name: "filter_id", persisted: true

  def create(conn, _params) do
    case Filters.make_filter_public(conn.assigns.filter) do
      {:ok, filter} ->
        conn
        |> put_flash(:info, "Successfully made filter public.")
        |> redirect(to: Routes.filter_path(conn, :show, filter))

      _error ->
        conn
        |> put_flash(:error, "Couldn't make filter public!")
        |> redirect(to: Routes.filter_path(conn, :show, conn.assigns.filter))
    end
  end
end
