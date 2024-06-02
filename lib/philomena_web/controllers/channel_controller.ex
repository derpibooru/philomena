defmodule PhilomenaWeb.ChannelController do
  use PhilomenaWeb, :controller

  alias Philomena.Channels
  alias Philomena.Channels.Channel
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource,
    model: Channel,
    only: [:show, :new, :create, :edit, :update, :delete]

  def index(conn, params) do
    show_nsfw? = conn.cookies["chan_nsfw"] == "true"

    channels =
      Channel
      |> maybe_show_nsfw(show_nsfw?)
      |> where([c], not is_nil(c.last_fetched_at))
      |> order_by(desc: :is_live, asc: :title)
      |> join(:left, [c], _ in assoc(c, :associated_artist_tag))
      |> preload([_c, t], associated_artist_tag: t)
      |> maybe_search(params)
      |> Repo.paginate(conn.assigns.scrivener)

    subscriptions = Channels.subscriptions(channels, conn.assigns.current_user)

    render(conn, "index.html",
      title: "Livestreams",
      layout_class: "layout--wide",
      channels: channels,
      subscriptions: subscriptions
    )
  end

  def show(conn, _params) do
    channel = conn.assigns.channel
    user = conn.assigns.current_user

    if user, do: Channels.clear_notification(channel, user)

    redirect(conn, external: channel_url(channel))
  end

  def new(conn, _params) do
    changeset = Channels.change_channel(%Channel{})
    render(conn, "new.html", title: "New Channel", changeset: changeset)
  end

  def create(conn, %{"channel" => channel_params}) do
    case Channels.create_channel(channel_params) do
      {:ok, _channel} ->
        conn
        |> put_flash(:info, "Channel created successfully.")
        |> redirect(to: ~p"/channels")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Channels.change_channel(conn.assigns.channel)
    render(conn, "edit.html", title: "Editing Channel", changeset: changeset)
  end

  def update(conn, %{"channel" => channel_params}) do
    case Channels.update_channel(conn.assigns.channel, channel_params) do
      {:ok, _channel} ->
        conn
        |> put_flash(:info, "Channel updated successfully.")
        |> redirect(to: ~p"/channels")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _channel} = Channels.delete_channel(conn.assigns.channel)

    conn
    |> put_flash(:info, "Channel destroyed successfully.")
    |> redirect(to: ~p"/channels")
  end

  defp maybe_search(query, %{"cq" => cq}) when is_binary(cq) and cq != "" do
    title_query = "#{cq}%"
    tag_query = "%#{cq}%"

    where(
      query,
      [c, t],
      ilike(c.title, ^title_query) or ilike(c.short_name, ^title_query) or
        ilike(t.name, ^tag_query)
    )
  end

  defp maybe_search(query, _params), do: query

  defp maybe_show_nsfw(query, true), do: query
  defp maybe_show_nsfw(query, _falsy), do: where(query, [c], c.nsfw == false)

  defp channel_url(%{type: "LivestreamChannel", short_name: short_name}),
    do: "http://www.livestream.com/#{short_name}"

  defp channel_url(%{type: "PicartoChannel", short_name: short_name}),
    do: "https://picarto.tv/#{short_name}"

  defp channel_url(%{type: "PiczelChannel", short_name: short_name}),
    do: "https://piczel.tv/watch/#{short_name}"

  defp channel_url(%{type: "TwitchChannel", short_name: short_name}),
    do: "https://www.twitch.tv/#{short_name}"
end
