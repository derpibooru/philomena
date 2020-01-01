defmodule PhilomenaWeb.Api.Json.ForumsController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ForumJson
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
    forum = 
      Forum
      |> where(id: ^id)
      |> Repo.one()

    cond do
      is_nil(forum) ->
        conn
        |> put_status(:not_found)
        |> text("")

      forum.access_level != "normal" ->
        conn
        |> put_status(:forbidden)
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
      |> preload([last_post: [:user, topic: :forum]])
      |> Repo.all()
      |> Enum.filter(&Canada.Can.can?(user, :show, &1))
    json(conn, %{forums: Enum.map(forums, &ForumJson.as_json/1)})
  end
end
