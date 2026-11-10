defmodule PhilomenaWeb.Api.Json.Search.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  def index(conn, params) do
    case Tags.query_tags(
           conn.assigns.actor,
           %{"query" => params["q"]},
           conn.assigns.pagination
         ) do
      {:ok, tags, _changeset} ->
        conn
        |> put_view(PhilomenaWeb.Api.Json.TagView)
        |> render("index.json", tags: tags, total: tags.total_entries)

      {:error, %Ecto.Changeset{} = changeset} ->
        {message, _options} = Keyword.fetch!(changeset.errors, :query)

        conn
        |> put_status(:bad_request)
        |> json(%{error: message})

      error ->
        error
    end
  end
end
