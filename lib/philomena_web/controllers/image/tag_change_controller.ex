defmodule PhilomenaWeb.Image.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.TagChanges.TagChange
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def index(conn, params) do
    image = conn.assigns.image

    tag_changes =
      TagChange
      |> where(image_id: ^image.id)
      |> added_filter(params)
      |> preload([:tag, :user, image: [:user, tags: :aliases]])
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Tag Changes on Image #{image.id}",
      image: image,
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
