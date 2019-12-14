defmodule PhilomenaWeb.ForumController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums, Forums.Forum, Topics.Topic}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Forum, id_field: "short_name"

  def index(conn, _params) do
    user = conn.assigns.current_user
    forums =
      Forum
      |> order_by(asc: :name)
      |> preload([last_post: [:user, topic: :forum]])
      |> Repo.all()
      |> Enum.filter(&Canada.Can.can?(user, :show, &1))

    topic_count = Repo.aggregate(Forum, :sum, :topic_count)

    render(conn, "index.html", forums: forums, topic_count: topic_count)
  end

  def show(conn, %{"id" => _id}) do
    forum = conn.assigns.forum
    user = conn.assigns.current_user

    topics =
      Topic
      |> where(forum_id: ^forum.id)
      |> where(hidden_from_users: false)
      |> order_by(desc: :sticky, desc: :last_replied_to_at)
      |> preload([:poll, :forum, :user, last_post: :user])
      |> Repo.paginate(conn.assigns.scrivener)

    watching = Forums.subscribed?(forum, user)

    render(conn, "show.html", forum: conn.assigns.forum, watching: watching, topics: topics)
  end
end
