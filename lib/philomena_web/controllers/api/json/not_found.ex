defmodule PhilomenaWeb.Api.Json.NotFound do
  @moduledoc """
  Standard 404 response for the JSON API.

  Every JSON API endpoint responds to a missing (or invisible) resource
  with status 404 and the body `{"error": "Not found"}`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc """
  Sends the standard JSON API 404 response on the given conn.
  """
  @spec not_found(Plug.Conn.t()) :: Plug.Conn.t()
  def not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end
end
