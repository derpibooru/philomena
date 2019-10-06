defmodule PhilomenaWeb.TopicController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum, Topics.Topic, Posts.Post}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true
  plug :load_and_authorize_resource, model: Topic, id_name: "id", id_field: "slug", preload: :user

  def show(conn, %{"id" => _id}) do
    posts =
      Post
      |> where(topic_id: ^conn.assigns.topic.id)
      |> order_by(asc: :created_at, asc: :id)
      |> preload([:user, topic: :forum])
      |> limit(25)
      |> Repo.all()

    render(conn, "show.html", posts: posts)
  end
end
