defmodule PhilomenaWeb.PchController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks.BadgeAwarder

  def index(conn, _params) do
    render(conn, title: "PCH Secret")
  end

  def create(conn, %{"event" => event_params}) do
    user = conn.assigns.current_user
    secret = event_secret()

    case event_params do
      %{"passphrase" => ^secret} ->
        {:ok, _badge} = BadgeAwarder.award_badge(user, user, "PonyCon Holland²")

        conn
        |> put_flash(:info, "Verification granted.")
        |> redirect(to: ~p"/")

      _ ->
        conn
        |> put_flash(:error, "Incorrect passphrase.")
        |> redirect(to: ~p"/")
    end
  end

  defp event_secret do
    Application.fetch_env!(:philomena, :event_secret)
  end
end
