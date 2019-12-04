defmodule PhilomenaWeb.Topic.Post.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.Reports
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show
  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true
  plug :load_topic
  plug :load_post

  def new(conn, _params) do
    topic = conn.assigns.topic
    post = conn.assigns.post
    action = Routes.forum_topic_post_report_path(conn, :create, topic.forum, topic, post)
    changeset =
      %Report{reportable_type: "Post", reportable_id: post.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html", reportable: post, changeset: changeset, action: action)
  end

  def create(conn, params) do
    topic = conn.assigns.topic
    post = conn.assigns.post
    action = Routes.forum_topic_post_report_path(conn, :create, topic.forum, topic, post)

    ReportController.create(conn, action, post, "Post", params)
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
      |> preload(topic: :forum)
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