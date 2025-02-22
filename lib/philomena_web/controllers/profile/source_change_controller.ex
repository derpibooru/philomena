defmodule PhilomenaWeb.Profile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Images.Image
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show

  plug :load_and_authorize_resource,
    model: User,
    id_name: "profile_id",
    id_field: "slug",
    persisted: true

  def index(conn, params) do
    user = conn.assigns.user

    common_query =
      SourceChange
      |> join(:inner, [sc], i in Image, on: sc.image_id == i.id)
      |> where(
        [sc, i],
        sc.user_id == ^user.id and not (i.user_id == ^user.id and i.anonymous == true)
      )
      |> added_filter(params)

    source_changes =
      common_query
      |> preload([:user, image: [:user, :sources, tags: :aliases]])
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    image_count =
      common_query
      |> select([_, i], count(i.id, :distinct))
      |> Repo.one()

    render(conn, "index.html",
      title: "Source Changes for User `#{user.name}'",
      user: user,
      source_changes: source_changes,
      image_count: image_count
    )
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query
end
