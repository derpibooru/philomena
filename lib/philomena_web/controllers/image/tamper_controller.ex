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

    {:ok, result} =
      ImageVotes.delete_vote_transaction(image, user)
      |> Repo.transaction()

    Images.reindex_image(image)

    conn
    |> put_flash(:info, "Vote removed.")
    |> PhilomenaWeb.ModerationLogPlug.call(
      details: &log_details/3,
      data: %{vote: result, image: image}
    )
    |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
  end

  defp log_details(conn, _action, data) do
    image = data.image

    vote_type =
      case data.vote do
        %{undownvote: {1, _}} -> "downvote"
        %{unupvote: {1, _}} -> "upvote"
        _ -> "vote"
      end

    %{
      body: "Deleted #{vote_type} by #{conn.assigns.user.name} on image >>#{data.image.id}",
      subject_path: Routes.image_path(conn, :show, image)
    }
  end
end
