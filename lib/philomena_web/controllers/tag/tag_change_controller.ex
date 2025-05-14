defmodule PhilomenaWeb.Tag.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.TagChanges

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_resource, model: Tag, id_name: "tag_id", id_field: "slug", persisted: true

  def index(conn, params) do
    tag = conn.assigns.tag

    render(conn, "index.html",
      title: "Tag Changes for Tag `#{tag.name}'",
      tag: tag,
      tag_changes:
        TagChanges.load(
          %{
            tag_id: tag.id,
            added: params["added"]
          },
          conn.assigns.scrivener
        )
    )
  end
end
