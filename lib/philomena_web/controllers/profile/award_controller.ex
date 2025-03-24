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
    user = conn.assigns.user

    case Badges.create_badge_award(conn.assigns.current_user, user, award_params) do
      {:ok, award} ->
        conn
        |> put_flash(:info, "Award successfully created.")
        |> moderation_log(details: &log_details/2, data: {user, award})
        |> redirect(to: ~p"/profiles/#{user}")

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
      {:ok, award} ->
        user = conn.assigns.user

        conn
        |> put_flash(:info, "Award successfully updated.")
        |> moderation_log(details: &log_details/2, data: {user, award})
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    user = conn.assigns.user
    {:ok, award} = Badges.delete_badge_award(conn.assigns.award)

    conn
    |> put_flash(:info, "Award successfully destroyed. By cruel and unusual means.")
    |> moderation_log(details: &log_details/2, data: {user, award})
    |> redirect(to: ~p"/profiles/#{user}")
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

  defp log_details(action, {user, award}) do
    award = Repo.preload(award, [:badge])

    body =
      case action do
        :create -> "Awarded badge '#{award.badge.title}' to #{user.name}"
        :update -> "Updated award of badge '#{award.badge.title}' on #{user.name}"
        :delete -> "Removed badge '#{award.badge.title}' from #{user.name}"
      end

    %{body: body, subject_path: ~p"/profiles/#{user}"}
  end
end
