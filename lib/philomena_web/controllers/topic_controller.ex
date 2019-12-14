defmodule PhilomenaWeb.TopicController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.{Forums.Forum, Topics.Topic, Posts.Post, Polls.Poll, PollOptions.PollOption}
  alias Philomena.{Forums, Topics, Posts}
  alias Philomena.Textile.Renderer
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:new, :create]
  plug PhilomenaWeb.AdvertPlug when action in [:show]

  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show
  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  def show(conn, %{"id" => slug} = params) do
    forum = conn.assigns.forum
    topic =
      Topic
      |> where(forum_id: ^forum.id, slug: ^slug)
      |> preload([:deleted_by, :user, poll: :options])
      |> Repo.one()

    user = conn.assigns.current_user

    Topics.clear_notification(topic, user)
    Forums.clear_notification(forum, user)

    # Update the notification ticker in the header
    conn = NotificationCountPlug.call(conn)

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
      |> preload([:deleted_by, :topic, topic: :forum, user: [awards: :badge]])
      |> Repo.all()

    rendered =
      Renderer.render_collection(posts, conn)

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

    changeset =
      %Post{}
      |> Posts.change_post()

    render(conn, "show.html", posts: posts, changeset: changeset, watching: watching)
  end

  def new(conn, _params) do
    changeset =
      %Topic{poll: %Poll{options: [%PollOption{}, %PollOption{}]}, posts: [%Post{}]}
      |> Topics.change_topic()

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"topic" => topic_params}) do
    attributes = conn.assigns.attributes
    forum = conn.assigns.forum

    case Topics.create_topic(forum, attributes, topic_params) do
      {:ok, %{topic: topic}} ->
        post = hd(topic.posts)
        Posts.reindex_post(post)
        Topics.notify_topic(topic)

        conn
        |> put_flash(:info, "Successfully posted topic.")
        |> redirect(to: Routes.forum_topic_path(conn, :show, forum, topic))

      {:error, :topic, changeset, _} ->
        conn
        |> render("new.html", changeset: changeset)

      _error ->
        conn
        |> put_flash(:error, "There was an error with your submission. Please try again.")
        |> redirect(to: Routes.forum_topic_path(conn, :new, forum))
    end
  end
end
