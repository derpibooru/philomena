defmodule PhilomenaWeb.Api.Json.ProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => id}) do
    case Users.show_profile(conn.assigns.actor, id) do
      {:ok, user} ->
        render(conn, "show.json", user: user)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
