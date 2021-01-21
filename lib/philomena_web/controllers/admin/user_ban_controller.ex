defmodule PhilomenaWeb.Admin.UserBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Bans.User, as: UserBan
  alias Philomena.Bans
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: UserBan, only: [:edit, :update, :delete]
  plug :check_can_delete when action in [:delete]

  def index(conn, %{"q" => q}) when is_binary(q) do
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

  def new(conn, %{"username" => username}) do
    changeset = Bans.change_user(%UserBan{username: username})
    render(conn, "new.html", title: "New User Ban", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Bans.change_user(%UserBan{})
    render(conn, "new.html", title: "New User Ban", changeset: changeset)
  end

  def create(conn, %{"user" => user_ban_params}) do
    case Bans.create_user(conn.assigns.current_user, user_ban_params) do
      {:ok, _user_ban} ->
        conn
        |> put_flash(:info, "User was successfully banned.")
        |> redirect(to: Routes.admin_user_ban_path(conn, :index))

      {:error, :user_ban, changeset, _changes} ->
        render(conn, "new.html", changeset: changeset)

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
      {:ok, _user_ban} ->
        conn
        |> put_flash(:info, "User ban successfully updated.")
        |> redirect(to: Routes.admin_user_ban_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _user_ban} = Bans.delete_user(conn.assigns.user)

    conn
    |> put_flash(:info, "User ban successfully deleted.")
    |> redirect(to: Routes.admin_user_ban_path(conn, :index))
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
end
