defmodule PhilomenaWeb.Api.Json.ForumController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    forums =
      Forum
      |> where(access_level: "normal")
      |> order_by(asc: :name)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, forums: forums, total: forums.total_entries)
  end

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
        render(conn, forum: forum)
    end
  end
end
