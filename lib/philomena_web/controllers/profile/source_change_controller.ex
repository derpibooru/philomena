defmodule PhilomenaWeb.Profile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges
  alias Philomena.SourceChanges.SourceChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"profile_id" => slug} = params) do
    case SourceChanges.list_user_source_changes(
           conn.assigns.actor,
           slug,
           params,
           conn.assigns.scrivener
         ) do
      {:ok,
       %SourceChangePage{
         target: user,
         source_changes: source_changes,
         image_count: image_count
       }, changeset} ->
        render(conn, "index.html",
          title: "Source Changes for User `#{user.name}'",
          user: user,
          source_changes: source_changes,
          image_count: image_count,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Invalid source change filter.")
        |> redirect(to: "/")

      error ->
        error
    end
  end
end
