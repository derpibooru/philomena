defmodule PhilomenaWeb.Filter.PublicController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"filter_id" => id}) do
    case Filters.create_filter_public(conn.assigns.actor, id) do
      {:ok, filter} ->
        conn
        |> put_flash(:info, "Successfully made filter public.")
        |> redirect(to: ~p"/filters/#{filter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Couldn't make filter public!")
        |> redirect(to: ~p"/filters/#{changeset.data}")

      {:error, _} = error ->
        error
    end
  end
end
