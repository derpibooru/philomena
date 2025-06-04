defmodule PhilomenaWeb.Topic.PollController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Polls
  alias Philomena.Repo

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.LoadPollPlug

  plug :verify_authorized
  plug :preload_options

  def edit(conn, _params) do
    changeset = Polls.change_poll(conn.assigns.poll)
    render(conn, "edit.html", title: "Editing Poll", changeset: changeset)
  end

  def update(conn, %{"poll" => poll_params}) do
    case Polls.update_poll(conn.assigns.poll, poll_params) do
      {:ok, _poll} ->
        conn
        |> put_flash(:info, "Poll successfully updated.")
        |> redirect(to: ~p"/forums/#{conn.assigns.forum}/topics/#{conn.assigns.topic}")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp preload_options(conn, _opts) do
    poll = Repo.preload(conn.assigns.poll, :options)

    assign(conn, :poll, poll)
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :hide, conn.assigns.topic) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
