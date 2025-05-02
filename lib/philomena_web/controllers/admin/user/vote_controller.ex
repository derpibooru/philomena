defmodule PhilomenaWeb.Admin.User.VoteController do
  use PhilomenaWeb, :controller

  alias Philomena.UserUnvoteWorker
  alias Philomena.Users.User

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def delete(conn, _params) do
    user = conn.assigns.user

    Exq.enqueue(Exq, "indexing", UserUnvoteWorker, [user.id, true])

    conn
    |> put_flash(:info, "Vote and fave wipe started.")
    |> moderation_log(details: &log_details/2, data: user)
    |> redirect(to: ~p"/profiles/#{user}")
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, User) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, user) do
    %{body: "Wiped votes and faves for #{user.name}", subject_path: ~p"/profiles/#{user}"}
  end
end
