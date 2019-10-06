defmodule PhilomenaWeb.ForumController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum, Topics.Topic}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Forum, id_field: "short_name"

  def index(conn, _params) do
    user = conn.assigns.current_user
    forums =
      Forum
      |> preload([last_post: [:topic, :user]])
      |> Repo.all()
      |> Enum.filter(&Canada.Can.can?(user, :show, &1))

    topic_count = Repo.aggregate(Forum, :sum, :topic_count)

    render(conn, "index.html", forums: forums, topic_count: topic_count)
  end

  def show(conn, %{"id" => _id}) do
    topics =
      Topic
      |> where(forum_id: ^conn.assigns.forum.id)
      |> where(hidden_from_users: false)
      |> order_by(desc: :sticky, desc: :last_replied_to_at)
      |> preload([:poll, :forum, :user, last_post: :user])
      |> limit(25)
      |> Repo.all()

    render(conn, "show.html", forum: conn.assigns.forum, topics: topics)
  end
end
