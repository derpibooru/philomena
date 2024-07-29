defmodule PhilomenaWeb.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def create(conn, %{"ids" => ids}) when is_list(ids) do
    attributes = conn.assigns.attributes

    attributes = %{
      ip: attributes[:ip],
      fingerprint: attributes[:fingerprint],
      user_id: attributes[:user].id
    }

    case TagChanges.mass_revert(ids, attributes) do
      {:ok, tag_changes} ->
        conn
        |> put_flash(:info, "Successfully reverted #{length(tag_changes)} tag changes.")
        |> redirect(external: conn.assigns.referrer)

      _error ->
        conn
        |> put_flash(:error, "Couldn't revert those tag changes!")
        |> redirect(external: conn.assigns.referrer)
    end
  end

  defp verify_authorized(conn, _params) do
    case Canada.Can.can?(conn.assigns.current_user, :revert, TagChange) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
