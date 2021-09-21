defmodule PhilomenaWeb.TopicController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.{Forums.Forum, Topics.Topic, Posts.Post, Polls.Poll, PollOptions.PollOption}
  alias Philomena.{Forums, Topics, Polls, Posts}
  alias Philomena.PollVotes
  alias PhilomenaWeb.TextRenderer
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.LimitPlug,
       [time: 300, error: "You may only make a new topic once every 5 minutes."]
       when action in [:create]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:new, :create]
  plug PhilomenaWeb.AdvertPlug when action in [:show]

  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show, update: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug, [param: "id"] when action in [:show, :update]
  plug :verify_authorized when action in [:update]

  def show(conn, params) do
    forum = conn.assigns.forum
    topic = conn.assigns.topic

    user = conn.assigns.current_user

    Topics.clear_notification(topic, user)
    Forums.clear_notification(forum, user)

    # Update the notification ticker in the header
    conn = NotificationCountPlug.call(conn)

    conn = conn |> assign(:topic, topic)
    %{page_number: page} = conn.assigns.pagination

    page =
      with {post_id, _extra} <- Integer.parse(params["post_id"] || ""),
           [post] <- Post |> where(id: ^post_id) |> Repo.all() do
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

    rendered = TextRenderer.render_collection(posts, conn)

    posts = Enum.zip(posts, rendered)

    posts = %Scrivener.Page{
      entries: posts,
      page_number: page,
      page_size: 25,
      total_entries: topic.post_count,
      total_pages: div(topic.post_count + 25 - 1, 25)
    }

    watching = Topics.subscribed?(topic, conn.assigns.current_user)

    voted = PollVotes.voted?(topic.poll, conn.assigns.current_user)

    poll_active = Polls.active?(topic.poll)

    changeset =
      %Post{}
      |> Posts.change_post()

    topic_changeset = Topics.change_topic(conn.assigns.topic)

    title = "#{topic.title} - #{forum.name} - Forums"

    render(conn, "show.html",
      title: title,
      posts: posts,
      changeset: changeset,
      topic_changeset: topic_changeset,
      watching: watching,
      voted: voted,
      poll_active: poll_active
    )
  end

  def new(conn, _params) do
    changeset =
      %Topic{poll: %Poll{options: [%PollOption{}, %PollOption{}]}, posts: [%Post{}]}
      |> Topics.change_topic()

    render(conn, "new.html", title: "New Topic", changeset: changeset)
  end

  def create(conn, %{"topic" => topic_params}) do
    attributes = conn.assigns.attributes
    forum = conn.assigns.forum

    case Topics.create_topic(forum, attributes, topic_params) do
      {:ok, %{topic: topic}} ->
        post = hd(topic.posts)
        Topics.notify_topic(topic, post)

        if forum.access_level == "normal" do
          PhilomenaWeb.Endpoint.broadcast!(
            "firehose",
            "post:create",
            PhilomenaWeb.Api.Json.Forum.Topic.PostView.render("firehose.json", %{
              post: post,
              topic: topic,
              forum: forum
            })
          )
        end

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

  def update(conn, %{"topic" => topic_params}) do
    case Topics.update_topic_title(conn.assigns.topic, topic_params) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Successfully updated topic.")
        |> redirect(to: Routes.forum_topic_path(conn, :show, conn.assigns.forum, topic))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "There was an error with your submission. Please try again.")
        |> redirect(
          to: Routes.forum_topic_path(conn, :show, conn.assigns.forum, conn.assigns.topic)
        )
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :edit, conn.assigns.topic) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
