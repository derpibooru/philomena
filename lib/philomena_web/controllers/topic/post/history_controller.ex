defmodule PhilomenaWeb.Topic.Post.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Versions.Version
  alias Philomena.Versions
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.LoadPostPlug

  def index(conn, _params) do
    post = conn.assigns.post

    versions =
      Version
      |> where(item_type: "Post", item_id: ^post.id)
      |> order_by(desc: :created_at)
      |> limit(25)
      |> Repo.all()
      |> Versions.load_data_and_associations(post)

    render(conn, "index.html", versions: versions)
  end
end
