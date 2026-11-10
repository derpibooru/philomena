defmodule PhilomenaWeb.ChannelController do
  use PhilomenaWeb, :controller

  alias Philomena.Channels

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    show_nsfw? = conn.cookies["chan_nsfw"] == "true"

    case Channels.list_channels(conn.assigns.actor, show_nsfw?, params, conn.assigns.scrivener) do
      {:ok, channels, subscriptions, changeset} ->
        render(conn, "index.html",
          title: "Livestreams",
          layout_class: "layout--wide",
          channels: channels,
          subscriptions: subscriptions,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "index.html",
          title: "Livestreams",
          layout_class: "layout--wide",
          channels: nil,
          subscriptions: %{},
          changeset: changeset
        )
    end
  end

  def show(conn, params) do
    with {:ok, channel} <- Channels.show_channel(conn.assigns.actor, params["id"]) do
      redirect(conn, external: channel_url(channel))
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- Channels.new_channel(conn.assigns.actor) do
      render(conn, "new.html", title: "New Channel", changeset: changeset)
    end
  end

  def create(conn, %{"channel" => channel_params}) do
    case Channels.create_channel(conn.assigns.actor, channel_params) do
      {:ok, _channel} ->
        conn
        |> put_flash(:info, "Channel created successfully.")
        |> redirect(to: ~p"/channels")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {channel, changeset}} <-
           Channels.edit_channel(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html", title: "Editing Channel", channel: channel, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "channel" => channel_params}) do
    case Channels.update_channel(conn.assigns.actor, id, channel_params) do
      {:ok, _channel} ->
        conn
        |> put_flash(:info, "Channel updated successfully.")
        |> redirect(to: ~p"/channels")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", channel: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, _channel} <- Channels.delete_channel(conn.assigns.actor, params["id"]) do
      conn
      |> put_flash(:info, "Channel destroyed successfully.")
      |> redirect(to: ~p"/channels")
    end
  end

  defp channel_url(%{type: "LivestreamChannel", short_name: short_name}),
    do: "http://www.livestream.com/#{short_name}"

  defp channel_url(%{type: "PicartoChannel", short_name: short_name}),
    do: "https://picarto.tv/#{short_name}"

  defp channel_url(%{type: "PiczelChannel", short_name: short_name}),
    do: "https://piczel.tv/watch/#{short_name}"

  defp channel_url(%{type: "TwitchChannel", short_name: short_name}),
    do: "https://www.twitch.tv/#{short_name}"
end
