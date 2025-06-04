defmodule PhilomenaWeb.TagChange.FullRevertController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def create(%{assigns: %{attributes: attributes}} = conn, params) do
    attributes = %{
      ip: to_string(attributes[:ip]),
      fingerprint: attributes[:fingerprint],
      user_id: attributes[:user].id,
      batch_size: attributes[:batch_size] || 100
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
    |> moderation_log(
      details: &log_details/2,
      data: %{user: conn.assigns.current_user, params: params}
    )
    |> redirect(external: conn.assigns.referrer)
  end

  defp verify_authorized(conn, _params) do
    if Canada.Can.can?(conn.assigns.current_user, :revert, TagChange) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, data) do
    {subject, subject_path} =
      case data.params do
        %{"user_id" => user_id} ->
          user = Users.get_user!(user_id)

          {"user #{user.name}", ~p"/profiles/#{user}"}

        %{"ip" => ip} ->
          {"ip #{ip}", ~p"/ip_profiles/#{ip}"}

        %{"fingerprint" => fp} ->
          {"fingerprint #{fp}", ~p"/fingerprint_profiles/#{fp}"}
      end

    %{body: "Reverted all tag changes for #{subject}", subject_path: subject_path}
  end
end
