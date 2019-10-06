defmodule PhilomenaWeb.TopicController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum, Topics.Topic, Posts.Post}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  def show(conn, %{"id" => slug}) do
    forum = conn.assigns.forum
    topic =
      Topic
      |> where(forum_id: ^forum.id, slug: ^slug, hidden_from_users: false)
      |> preload(:user)
      |> Repo.one()

    conn = conn |> assign(:topic, topic)

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
