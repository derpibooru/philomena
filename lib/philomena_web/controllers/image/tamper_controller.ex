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
    |> moderation_log(
      details: &log_details/2,
      data: %{vote: result, image: image, username: conn.assigns.user.name}
    )
    |> redirect(to: ~p"/images/#{conn.assigns.image}")
  end

  defp log_details(_action, data) do
    image = data.image

    vote_type =
      case data.vote do
        %{undownvote: {1, _}} -> "downvote"
        %{unupvote: {1, _}} -> "upvote"
        _ -> "vote"
      end

    %{
      body: "Deleted #{vote_type} by #{data.username} on image #{data.image.id}",
      subject_path: ~p"/images/#{image}"
    }
  end
end
