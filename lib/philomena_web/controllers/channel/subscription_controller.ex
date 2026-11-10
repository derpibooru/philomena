defmodule PhilomenaWeb.Channel.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Channels

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Channels.create_channel_subscription(conn.assigns.actor, params["channel_id"]) do
      {:ok, channel} ->
        render(conn, "_subscription.html", channel: channel, watching: true, layout: false)

      {:error, %Ecto.Changeset{}} ->
        render(conn, "_error.html", layout: false)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, channel} <-
           Channels.delete_channel_subscription(conn.assigns.actor, params["channel_id"]) do
      render(conn, "_subscription.html", channel: channel, watching: false, layout: false)
    end
  end
end
