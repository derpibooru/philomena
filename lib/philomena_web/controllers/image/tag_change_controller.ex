defmodule PhilomenaWeb.Image.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  plug :load_and_authorize_resource,
    model: TagChange,
    preload: [:tag],
    persisted: true,
    only: [:delete]

  def index(conn, params) do
    image = conn.assigns.image

    tag_changes =
      TagChange
      |> where(image_id: ^image.id)
      |> added_filter(params)
      |> preload([:tag, :user, image: [:user, :sources, tags: :aliases]])
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Tag Changes on Image #{image.id}",
      image: image,
      tag_changes: tag_changes
    )
  end

  def delete(conn, _params) do
    image = conn.assigns.image
    tag_change = conn.assigns.tag_change

    TagChanges.delete_tag_change(tag_change)

    conn
    |> put_flash(:info, "Successfully deleted tag change from history.")
    |> moderation_log(
      details: &log_details/2,
      data: %{image: image, details: tag_change_details(tag_change)}
    )
    |> redirect(to: ~p"/images/#{image}")
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query

  defp log_details(_action, %{image: image, details: details}) do
    %{
      body: "Deleted tag change #{details} on image #{image.id} from history",
      subject_path: ~p"/images/#{image}"
    }
  end

  defp tag_change_details(%TagChange{added: true, tag: %Tag{name: tag_name}}),
    do: "+#{tag_name}"

  defp tag_change_details(%TagChange{added: true, tag_name_cache: tag_name}),
    do: "+#{tag_name}"

  defp tag_change_details(%TagChange{added: false, tag: %Tag{name: tag_name}}),
    do: "-#{tag_name}"

  defp tag_change_details(%TagChange{added: false, tag_name_cache: tag_name}),
    do: "-#{tag_name}"
end
