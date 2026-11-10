defmodule PhilomenaWeb.Topic.Post.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "post_id" => post_id}) do
    locator = {:post, forum_id, topic_id, post_id}

    with {:ok, form} <- Reports.new_report(conn.assigns.actor, locator) do
      post = form.target
      topic = post.topic
      action = ~p"/forums/#{topic.forum}/topics/#{topic}/posts/#{post}/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        subject: post,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(
        conn,
        %{"forum_id" => forum_id, "topic_id" => topic_id, "post_id" => post_id} = params
      ) do
    ReportController.create(
      conn,
      {:post, forum_id, topic_id, post_id},
      fn post ->
        ~p"/forums/#{post.topic.forum}/topics/#{post.topic}/posts/#{post}/reports"
      end,
      params
    )
  end
end
