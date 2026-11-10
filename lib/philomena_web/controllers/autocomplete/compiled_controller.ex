defmodule PhilomenaWeb.Autocomplete.CompiledController do
  use PhilomenaWeb, :controller

  alias Philomena.Autocomplete

  def show(conn, _params) do
    case Autocomplete.show_compiled_autocomplete() do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> configure_session(drop: true)
        |> text("")

      {:ok, %{content: content}} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> configure_session(drop: true)
        |> resp(200, content)
    end
  end
end
