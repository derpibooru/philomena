defmodule PhilomenaWeb.Api.Json.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => slug}) do
    case Tags.show_tag(conn.assigns.actor, slug) do
      {:ok, tag} ->
        render(conn, "show.json", tag: tag)

      {:error, :not_found} ->
        not_found(conn)

      error ->
        error
    end
  end
end
