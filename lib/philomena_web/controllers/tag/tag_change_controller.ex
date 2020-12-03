defmodule PhilomenaWeb.Tag.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.TagChanges.TagChange
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_resource, model: Tag, id_name: "tag_id", id_field: "slug", persisted: true

  def index(conn, params) do
    tag = conn.assigns.tag

    tag_changes =
      TagChange
      |> where(tag_id: ^tag.id)
      |> added_filter(params)
      |> preload([:tag, :user, image: [:user, tags: :aliases]])
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Tag Changes for Tag `#{tag.name}'",
      tag: tag,
      tag_changes: tag_changes
    )
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query
end
