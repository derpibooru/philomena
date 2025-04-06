defmodule PhilomenaWeb.Admin.UserBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.Bans.User, as: UserBan
  alias Philomena.Bans
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: UserBan, only: [:edit, :update, :delete], preload: :user
  plug :check_can_delete when action in [:delete]

  def index(conn, %{"bq" => q}) when is_binary(q) do
    like_q = "%#{q}%"

    UserBan
    |> join(:inner, [ub], _ in assoc(ub, :user))
    |> where(
      [ub, u],
      ilike(u.name, ^like_q) or
        ub.generated_ban_id == ^q or
        fragment("to_tsvector(?) @@ plainto_tsquery(?)", ub.reason, ^q) or
        fragment("to_tsvector(?) @@ plainto_tsquery(?)", ub.note, ^q)
    )
    |> load_bans(conn)
  end

  def index(conn, %{"user_id" => user_id}) when is_binary(user_id) do
    UserBan
    |> where(user_id: ^user_id)
    |> load_bans(conn)
  end

  def index(conn, _params) do
    load_bans(UserBan, conn)
  end

  def new(conn, %{"user_id" => id}) do
    target_user = Users.get_user!(id)
    changeset = Bans.change_user(Ecto.build_assoc(target_user, :bans))

    render(conn, "new.html",
      title: "New User Ban",
      target_user: target_user,
      changeset: changeset
    )
  end

  def new(conn, _params) do
    conn
    |> put_flash(:error, "Must create ban on user.")
    |> redirect(to: ~p"/admin/user_bans")
  end

  def create(conn, %{"user" => user_ban_params}) do
    case Bans.create_user(conn.assigns.current_user, user_ban_params) do
      {:ok, user_ban} ->
        conn
        |> put_flash(:info, "User was successfully banned.")
        |> moderation_log(details: &log_details/2, data: user_ban)
        |> redirect(to: ~p"/admin/user_bans")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Bans.change_user(conn.assigns.user)
    render(conn, "edit.html", title: "Editing User Ban", changeset: changeset)
  end

  def update(conn, %{"user" => user_ban_params}) do
    case Bans.update_user(conn.assigns.user, user_ban_params) do
      {:ok, user_ban} ->
        conn
        |> put_flash(:info, "User ban successfully updated.")
        |> moderation_log(details: &log_details/2, data: user_ban)
        |> redirect(to: ~p"/admin/user_bans")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, user_ban} = Bans.delete_user(conn.assigns.user)

    conn
    |> put_flash(:info, "User ban successfully deleted.")
    |> moderation_log(details: &log_details/2, data: user_ban)
    |> redirect(to: ~p"/admin/user_bans")
  end

  defp load_bans(queryable, conn) do
    user_bans =
      queryable
      |> order_by(desc: :created_at)
      |> preload([:user, :banning_user])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Admin - User Bans",
      layout_class: "layout--wide",
      user_bans: user_bans
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, UserBan) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp check_can_delete(conn, _opts) do
    case conn.assigns.current_user.role == "admin" do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(action, ban) do
    body =
      case action do
        :create -> "Created a user ban #{ban.generated_ban_id}"
        :update -> "Updated a user ban #{ban.generated_ban_id}"
        :delete -> "Deleted a user ban #{ban.generated_ban_id}"
      end

    %{body: body, subject_path: ~p"/admin/user_bans"}
  end
end
