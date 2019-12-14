defmodule PhilomenaWeb.Image.Comment.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Versions.Version
  alias Philomena.Versions
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  plug PhilomenaWeb.LoadCommentPlug

  def index(conn, _params) do
    comment = conn.assigns.comment

    versions =
      Version
      |> where(item_type: "Comment", item_id: ^comment.id)
      |> order_by(desc: :created_at)
      |> limit(25)
      |> Repo.all()
      |> Versions.load_data_and_associations(comment)

    render(conn, "index.html", versions: versions)
  end
end
