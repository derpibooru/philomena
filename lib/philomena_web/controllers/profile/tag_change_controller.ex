defmodule PhilomenaWeb.Profile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"profile_id" => profile_id} = params) do
    case TagChanges.list_user_tag_changes(
           conn.assigns.actor,
           profile_id,
           params,
           conn.assigns.pagination
         ) do
      {:ok, %TagChangePage{target: user, tag_changes: tag_changes}, changeset} ->
        path = ~p"/profiles/#{user}/tag_changes"

        conn
        |> put_view(PhilomenaWeb.TagChangeView)
        |> render("index.html",
          title: "Tag Changes for User `#{user.name}'",
          path: path,
          pagination_route: fn query -> "#{path}?#{Plug.Conn.Query.encode(query)}" end,
          tag_changes: tag_changes,
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
end
