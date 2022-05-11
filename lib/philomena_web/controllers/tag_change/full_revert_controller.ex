defmodule PhilomenaWeb.TagChange.FullRevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def create(conn, params) do
    attributes = conn.assigns.attributes

    attributes = %{
      ip: to_string(attributes[:ip]),
      fingerprint: attributes[:fingerprint],
      referrer: attributes[:referrer],
      user_agent: attributes[:referrer],
      user_id: attributes[:user].id
    }

    case params do
      %{"user_id" => user_id} ->
        TagChanges.full_revert(%{user_id: user_id, attributes: attributes})

      %{"ip" => ip} ->
        TagChanges.full_revert(%{ip: ip, attributes: attributes})

      %{"fingerprint" => fp} ->
        TagChanges.full_revert(%{fingerprint: fp, attributes: attributes})
    end

    conn
    |> put_flash(:info, "Reversion of tag changes enqueued.")
    |> redirect(external: conn.assigns.referrer)
  end

  defp verify_authorized(conn, _params) do
    case Canada.Can.can?(conn.assigns.current_user, :revert, TagChange) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
