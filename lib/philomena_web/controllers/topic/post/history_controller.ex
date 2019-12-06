defmodule PhilomenaWeb.Topic.Post.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Versions.Version
  alias Philomena.Versions
  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true
  plug :load_topic
  plug :load_post

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

  defp load_topic(conn, _opts) do
    user = conn.assigns.current_user
    forum = conn.assigns.forum
    topic =
      Topic
      |> where(forum_id: ^forum.id, slug: ^conn.params["topic_id"])
      |> preload(:forum)
      |> Repo.one()

    cond do
      is_nil(topic) ->
        PhilomenaWeb.NotFoundPlug.call(conn)

      not Canada.Can.can?(user, :show, topic) ->
        PhilomenaWeb.NotAuthorizedPlug.call(conn)

      true ->
        Plug.Conn.assign(conn, :topic, topic)
    end
  end

  defp load_post(conn, _opts) do
    user = conn.assigns.current_user
    topic = conn.assigns.topic

    post =
      Post
      |> where(topic_id: ^topic.id, id: ^conn.params["post_id"])
      |> preload(topic: :forum, user: [awards: :badge])
      |> Repo.one()

      cond do
        is_nil(post) ->
          PhilomenaWeb.NotFoundPlug.call(conn)

        not Canada.Can.can?(user, :show, post) ->
          PhilomenaWeb.NotAuthorizedPlug.call(conn)

        true ->
          Plug.Conn.assign(conn, :post, post)
      end
  end
end