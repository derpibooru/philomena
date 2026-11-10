defmodule PhilomenaWeb.Api.Json.FilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => id}) do
    case Filters.show_filter(conn.assigns.actor, id) do
      {:ok, filter} ->
        render(conn, "show.json", filter: filter)

      # A filter the viewer may not see and a missing filter answer with the
      # same uniform 404.
      {:error, _not_found_or_unauthorized} ->
        not_found(conn)
    end
  end
end
