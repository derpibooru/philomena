defmodule PhilomenaWeb.Api.Json.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
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
        render(conn, "show.json", image: image)
    end
  end
end
