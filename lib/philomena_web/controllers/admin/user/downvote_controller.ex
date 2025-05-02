defmodule PhilomenaWeb.Admin.User.DownvoteController do
  use PhilomenaWeb, :controller

  alias Philomena.UserUnvoteWorker
  alias Philomena.Users.User

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def delete(conn, _params) do
    user = conn.assigns.user

    Exq.enqueue(Exq, "indexing", UserUnvoteWorker, [user.id, false])

    conn
    |> put_flash(:info, "Downvote wipe started.")
    |> moderation_log(details: &log_details/2, data: user)
    |> redirect(to: ~p"/profiles/#{user}")
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, user) do
    %{body: "Wiped downvotes for #{user.name}", subject_path: ~p"/profiles/#{user}"}
  end
end
