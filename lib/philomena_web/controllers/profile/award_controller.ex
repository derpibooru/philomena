defmodule PhilomenaWeb.Profile.AwardController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"profile_id" => slug}) do
    with {:ok, {user, changeset, badges}} <-
           Badges.new_award(conn.assigns.actor, slug) do
      render(conn, "new.html",
        title: "New Award",
        user: user,
        changeset: changeset,
        badges: badges
      )
    end
  end

  def create(conn, %{"profile_id" => slug, "award" => award_params}) do
    case Badges.create_award(conn.assigns.actor, slug, award_params) do
      {:ok, {user, _award}} ->
        conn
        |> put_flash(:info, "Award successfully created.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, {user, changeset, badges}} ->
        render(conn, "new.html",
          user: user,
          changeset: changeset,
          badges: badges
        )

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, %{"profile_id" => slug, "id" => id}) do
    with {:ok, {user, award, changeset, badges}} <-
           Badges.edit_award(conn.assigns.actor, slug, id) do
      render(conn, "edit.html",
        title: "Editing Award",
        user: user,
        award: award,
        changeset: changeset,
        badges: badges
      )
    end
  end

  def update(conn, %{"profile_id" => slug, "id" => id, "award" => award_params}) do
    case Badges.update_award(conn.assigns.actor, slug, id, award_params) do
      {:ok, {user, _award}} ->
        conn
        |> put_flash(:info, "Award successfully updated.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, {user, award, changeset, badges}} ->
        render(conn, "edit.html",
          user: user,
          award: award,
          changeset: changeset,
          badges: badges
        )

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, %{"profile_id" => slug, "id" => id}) do
    with {:ok, {user, _award}} <- Badges.delete_award(conn.assigns.actor, slug, id) do
      conn
      |> put_flash(:info, "Award successfully destroyed. By cruel and unusual means.")
      |> redirect(to: ~p"/profiles/#{user}")
    end
  end
end
