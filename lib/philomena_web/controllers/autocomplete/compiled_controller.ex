defmodule PhilomenaWeb.Autocomplete.CompiledController do
  use PhilomenaWeb, :controller

  alias Philomena.Autocomplete

  def show(conn, _params) do
    autocomplete = Autocomplete.get_autocomplete()

    case autocomplete do
      nil ->
        conn
        |> put_status(:not_found)
        |> configure_session(drop: true)
        |> text("")

      %{content: content} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> configure_session(drop: true)
        |> resp(200, content)
    end
  end
end
