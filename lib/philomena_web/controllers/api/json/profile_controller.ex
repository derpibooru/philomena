defmodule PhilomenaWeb.Api.Json.ProfileController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.UserJson
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
    profile =
      User
      |> where(id: ^id)
      |> preload(public_links: :tag, awards: :badge)
      |> Repo.one()

    cond do
      is_nil(profile) or profile.deleted_at ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{user: UserJson.as_json(conn, profile)})
    end
  end
end
