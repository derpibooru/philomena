defmodule PhilomenaWeb.Profile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.TagChanges.TagChange
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_resource, model: User, id_name: "profile_id", id_field: "slug", persisted: true

  def index(conn, params) do
    user = conn.assigns.user

    tag_changes =
      TagChange
      |> join(:inner, [tc], i in Image, on: tc.image_id == i.id)
      |> only_tag_join(params)
      |> where(
        [tc, i],
        tc.user_id == ^user.id and not (i.user_id == ^user.id and i.anonymous == true)
      )
      |> added_filter(params)
      |> only_tag_filter(params)
      |> preload([:tag, :user, image: [:user, :sources, tags: :aliases]])
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    # params.permit(:added, :only_tag) ...
    pagination_params =
      [added: conn.params["added"], only_tag: conn.params["only_tag"]]
      |> Keyword.filter(fn {k, _v} -> Map.has_key?(conn.params, "#{k}") end)

    render(conn, "index.html",
      title: "Tag Changes for User `#{user.name}'",
      user: user,
      tag_changes: tag_changes,
      pagination_params: pagination_params
    )
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query

  defp only_tag_join(query, %{"only_tag" => only_tag}) when only_tag != "",
    do: join(query, :inner, [tc], t in Tag, on: tc.tag_id == t.id)

  defp only_tag_join(query, _params),
    do: query

  defp only_tag_filter(query, %{"only_tag" => only_tag}) when only_tag != "",
    do: where(query, [_, _, t], t.name == ^only_tag)

  defp only_tag_filter(query, _params),
    do: query
end
