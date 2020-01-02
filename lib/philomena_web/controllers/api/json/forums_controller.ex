defmodule PhilomenaWeb.Api.Json.ForumController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ForumJson
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
    forum = 
      Forum
      |> where(short_name: ^id)
      |> where(access_level: "normal")
      |> Repo.one()

    cond do
      is_nil(forum) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{forum: ForumJson.as_json(forum)})
    end
  end

  def index(conn, _params) do
    user = conn.assigns.current_user
    forums =
      Forum
      |> order_by(asc: :name)
      |> where(access_level: "normal")
      |> preload([last_post: [:user, topic: :forum]])
      |> Repo.all()

    json(conn, %{forums: Enum.map(forums, &ForumJson.as_json/1)})
  end
end
