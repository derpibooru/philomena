defmodule PhilomenaWeb.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    # The template reads the effective query back out of conn.params["tcq"],
    # so the default must be written there when the parameter is absent.
    params = update_in(params["tcq"], &(&1 || "created_at.gte:1 week ago"))
    conn = put_in(conn.params, params)

    case TagChanges.list_tag_changes(conn.assigns.actor, params, conn.assigns.pagination) do
      {:ok, %TagChangePage{} = page, changeset} ->
        render(conn, "index.html",
          title: "Tag Changes",
          path: ~p"/tag_changes",
          pagination_route: fn query -> ~p"/tag_changes?#{query}" end,
          tag_changes: page.tag_changes,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Invalid tag change query.")
        |> redirect(to: "/tag_changes")

      error ->
        error
    end
  end

  def delete(conn, params) do
    case TagChanges.delete_tag_change(conn.assigns.actor, params["id"]) do
      {:ok, _tag_change} ->
        conn
        |> put_flash(:info, "Successfully deleted tag change from history.")
        |> redirect(external: conn.assigns.referrer)

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to delete tag change from history.")
        |> redirect(external: conn.assigns.referrer)

      {:error, _} = error ->
        error
    end
  end
end
