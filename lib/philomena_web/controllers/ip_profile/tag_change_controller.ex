defmodule PhilomenaWeb.IpProfile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"ip_profile_id" => ip} = params) do
    case TagChanges.list_ip_tag_changes(conn.assigns.actor, ip, params, conn.assigns.pagination) do
      {:ok, %TagChangePage{target: normalized_ip, tag_changes: tag_changes}, changeset} ->
        ip = to_string(normalized_ip)
        path = ~p"/ip_profiles/#{ip}/tag_changes"

        conn
        |> put_view(PhilomenaWeb.TagChangeView)
        |> render("index.html",
          title: "Tag Changes for IP `#{ip}'",
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
