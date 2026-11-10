defmodule PhilomenaWeb.Profile.ScratchpadController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, %{"profile_id" => slug}) do
    with {:ok, %Ecto.Changeset{} = changeset} <-
           Users.edit_profile_scratchpad(conn.assigns.actor, slug) do
      render(conn, "edit.html",
        title: "Editing Moderation Scratchpad",
        changeset: changeset,
        user: changeset.data
      )
    end
  end

  def update(conn, %{"profile_id" => slug, "user" => user_params}) do
    case Users.update_profile_scratchpad(conn.assigns.actor, slug, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Moderation scratchpad successfully updated.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset, user: changeset.data)

      {:error, _} = error ->
        error
    end
  end
end
