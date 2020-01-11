defmodule PhilomenaWeb.Profile.AwardController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges.Award
  alias Philomena.Badges.Badge
  alias Philomena.Users.User
  alias Philomena.Badges
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "profile_id", id_field: "slug", persisted: true
  plug :load_resource, model: Award, only: [:edit, :update, :delete]
  plug :load_badges when action in [:new, :create, :edit, :update]

  def new(conn, _params) do
    changeset = Badges.change_badge_award(%Award{})
    render(conn, "new.html", title: "New Award", changeset: changeset)
  end

  def create(conn, %{"award" => award_params}) do
    case Badges.create_badge_award(conn.assigns.current_user, conn.assigns.user, award_params) do
      {:ok, _award} ->
        conn
        |> put_flash(:info, "Award successfully created.")
        |> redirect(to: Routes.profile_path(conn, :show, conn.assigns.user))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Badges.change_badge_award(conn.assigns.award)
    render(conn, "edit.html", title: "Editing Award", changeset: changeset)
  end

  def update(conn, %{"award" => award_params}) do
    case Badges.update_badge_award(conn.assigns.award, award_params) do
      {:ok, _award} ->
        conn
        |> put_flash(:info, "Award successfully updated.")
        |> redirect(to: Routes.profile_path(conn, :show, conn.assigns.user))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _award} = Badges.delete_badge_award(conn.assigns.award)

    conn
    |> put_flash(:info, "Award successfully destroyed. By cruel and unusual means.")
    |> redirect(to: Routes.profile_path(conn, :show, conn.assigns.user))
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :create, Award) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp load_badges(conn, _opts) do
    badges =
      Badge
      |> where(disable_award: false)
      |> order_by(asc: :title)
      |> Repo.all()

    assign(conn, :badges, badges)
  end
end
