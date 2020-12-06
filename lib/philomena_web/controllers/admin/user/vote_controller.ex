defmodule PhilomenaWeb.Admin.User.VoteController do
  use PhilomenaWeb, :controller

  alias Philomena.UserUnvoteWorker
  alias Philomena.Users.User

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def delete(conn, _params) do
    Exq.enqueue(Exq, "indexing", UserUnvoteWorker, [conn.assigns.user.id, true])

    conn
    |> put_flash(:info, "Vote and fave wipe started.")
    |> redirect(to: Routes.profile_path(conn, :show, conn.assigns.user))
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
