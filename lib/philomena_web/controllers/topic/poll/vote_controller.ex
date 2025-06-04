defmodule PhilomenaWeb.Topic.Poll.VoteController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.PollOptions.PollOption
  alias Philomena.PollVotes
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, index: :show, create: :show, delete: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.LoadPollPlug

  plug :verify_authorized when action in [:index, :delete]

  def index(conn, _params) do
    poll = conn.assigns.poll

    options =
      PollOption
      |> where(poll_id: ^poll.id)
      |> preload(poll_votes: :user)
      |> Repo.all()
      |> Enum.filter(&(&1.vote_count > 0))

    render(conn, "index.html", layout: false, options: options)
  end

  def create(conn, %{"poll" => poll_params}) do
    poll = conn.assigns.poll
    topic = conn.assigns.topic

    case PollVotes.create_poll_votes(conn.assigns.current_user, poll, poll_params) do
      {:ok, _votes} ->
        conn
        |> put_flash(:info, "Your vote has been recorded.")
        |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")

      _error ->
        conn
        |> put_flash(:error, "Your vote was not recorded.")
        |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")
    end
  end

  def create(conn, _params) do
    topic = conn.assigns.topic

    conn
    |> put_flash(:error, "Your vote was not recorded.")
    |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")
  end

  def delete(conn, %{"id" => poll_vote_id}) do
    topic = conn.assigns.topic
    poll_vote = PollVotes.get_poll_vote!(poll_vote_id)

    {:ok, _poll_vote} = PollVotes.delete_poll_vote(poll_vote)

    conn
    |> put_flash(:info, "Vote successfully removed.")
    |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :hide, conn.assigns.topic) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
