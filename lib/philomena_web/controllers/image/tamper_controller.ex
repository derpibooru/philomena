defmodule PhilomenaWeb.Image.TamperController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Images.Image
  alias Philomena.Images

  alias Philomena.ImageVotes
  alias Philomena.Repo

  plug PhilomenaWeb.CanaryMapPlug, create: :tamper
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :load_resource, model: User, id_name: "user_id", persisted: true

  def create(conn, _params) do
    image = conn.assigns.image
    user = conn.assigns.user

    {:ok, _result} =
      ImageVotes.delete_vote_transaction(image, user)
      |> Repo.transaction()

    Images.reindex_image(image)

    conn
    |> put_flash(:info, "Vote removed.")
    |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
  end
end
