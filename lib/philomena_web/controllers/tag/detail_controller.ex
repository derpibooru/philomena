defmodule PhilomenaWeb.Tag.DetailController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Filters.Filter
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: Tag, id_name: "tag_id", id_field: "slug", persisted: true

  def index(conn, _params) do
    tag = conn.assigns.tag

    filters_spoilering =
      Filter
      |> where([f], fragment("? @> ARRAY[?]::integer[]", f.spoilered_tag_ids, ^tag.id))
      |> preload(:user)
      |> Repo.all()

    filters_hiding =
      Filter
      |> where([f], fragment("? @> ARRAY[?]::integer[]", f.hidden_tag_ids, ^tag.id))
      |> preload(:user)
      |> Repo.all()

    users_watching =
      User
      |> where([u], fragment("? @> ARRAY[?]::integer[]", u.watched_tag_ids, ^tag.id))
      |> Repo.all()

    render(
      conn,
      "index.html",
      title: "Tag Usage for Tag `#{tag.name}'",
      filters_spoilering: filters_spoilering,
      filters_hiding: filters_hiding,
      users_watching: users_watching
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :edit, %Tag{}) do
      true   -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
