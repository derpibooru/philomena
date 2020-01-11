defmodule PhilomenaWeb.Api.Json.PostController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.PostJson
  alias Philomena.Posts.Post
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => post_id}) do
    post =
      Post
      |> join(:inner, [p], _ in assoc(p, :topic))
      |> join(:inner, [_p, t], _ in assoc(t, :forum))
      |> where(id: ^post_id)
      |> where(destroyed_content: false)
      |> where([_p, t], t.hidden_from_users == false)
      |> where([_p, _t, f], f.access_level == "normal")
      |> preload([:user, :topic])
      |> Repo.one()

    cond do
      is_nil(post) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{post: PostJson.as_json(post)})
    end
  end
end
