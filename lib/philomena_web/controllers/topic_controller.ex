defmodule PhilomenaWeb.TopicController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum, Topics, Topics.Topic, Posts.Post, Textile.Renderer}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  def show(conn, %{"id" => slug} = params) do
    forum = conn.assigns.forum
    topic =
      Topic
      |> where(forum_id: ^forum.id, slug: ^slug, hidden_from_users: false)
      |> preload(:user)
      |> Repo.one()

    conn = conn |> assign(:topic, topic)
    %{page_number: page} = conn.assigns.pagination

    page =
      with {post_id, _extra} <- Integer.parse(params["post_id"] || ""),
           [post] <- Post |> where(id: ^post_id) |> Repo.all()
      do
        div(post.topic_position, 25) + 1
      else
        _ ->
          page
      end

    posts =
      Post
      |> where(topic_id: ^conn.assigns.topic.id)
      |> where([p], p.topic_position >= ^(25 * (page - 1)) and p.topic_position < ^(25 * page))
      |> order_by(asc: :created_at)
      |> preload([topic: :forum, user: [awards: :badge]])
      |> Repo.all()

    rendered =
      Renderer.render_collection(posts)

    posts =
      Enum.zip(posts, rendered)

    posts =
      %Scrivener.Page{
        entries: posts,
        page_number: page,
        page_size: 25,
        total_entries: topic.post_count,
        total_pages: div(topic.post_count + 25 - 1, 25)
      }

    watching =
      Topics.subscribed?(topic, conn.assigns.current_user)

    render(conn, "show.html", posts: posts, watching: watching)
  end
end
