defmodule PhilomenaWeb.FingerprintProfile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"fingerprint_profile_id" => fingerprint} = params) do
    case TagChanges.list_fingerprint_tag_changes(
           conn.assigns.actor,
           fingerprint,
           params,
           conn.assigns.pagination
         ) do
      {:ok, %TagChangePage{target: fingerprint, tag_changes: tag_changes}, changeset} ->
        path = ~p"/fingerprint_profiles/#{fingerprint}/tag_changes"

        conn
        |> put_view(PhilomenaWeb.TagChangeView)
        |> render("index.html",
          title: "Tag Changes for Fingerprint `#{fingerprint}'",
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
