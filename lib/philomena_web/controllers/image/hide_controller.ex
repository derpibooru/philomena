defmodule PhilomenaWeb.Image.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images, Images.Image}
  alias Philomena.ImageHides
  alias Philomena.Repo
  alias Ecto.Multi

  plug PhilomenaWeb.Plugs.FilterBannedUsers
  plug PhilomenaWeb.Plugs.CanaryMapPlug, create: :vote, delete: :vote
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    user = conn.assigns.current_user
    image = conn.assigns.image

    Multi.append(
      ImageHides.delete_hide_transaction(image, user),
      ImageHides.create_hide_transaction(image, user)
    )
    |> Repo.transaction()
    |> case do
      {:ok, _result} ->
        image =
          Images.get_image!(image.id)
          |> Images.reindex_image()

        conn
        |> json(Image.interaction_data(image))

      _error ->
        conn
        |> Plug.Conn.put_status(409)
        |> json(%{})
    end
  end

  def delete(conn, _params) do
    user = conn.assigns.current_user
    image = conn.assigns.image

    ImageHides.delete_hide_transaction(image, user)
    |> Repo.transaction()
    |> case do
      {:ok, _result} ->
        image =
          Images.get_image!(image.id)
          |> Images.reindex_image()

        conn
        |> json(Image.interaction_data(image))

      _error ->
        conn
        |> Plug.Conn.put_status(409)
        |> json(%{})
    end
  end
end