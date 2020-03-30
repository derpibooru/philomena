defmodule PhilomenaWeb.Api.Json.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Interactions
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    image =
      Image
      |> where(id: ^id)
      |> preload([:tags, :user, :intensity])
      |> Repo.one()

    case image do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("")

      _ ->
        interactions = Interactions.user_interactions([image], user)

        render(conn, "show.json", image: image, interactions: interactions)
    end
  end
end
