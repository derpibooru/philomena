defmodule PhilomenaWeb.ChannelController do
  use PhilomenaWeb, :controller

  alias Philomena.Channels
  alias Philomena.Channels.Channel
  alias Philomena.Repo
  import Ecto.Query

  plug :load_resource, model: Channel

  def index(conn, _params) do
    show_nsfw? = conn.cookies["chan_nsfw"] == "true"
    channels =
      Channel
      |> maybe_show_nsfw(show_nsfw?)
      |> where([c], not is_nil(c.last_fetched_at))
      |> order_by(desc: :is_live, asc: :title)
      |> preload(:associated_artist_tag)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", layout_class: "layout--wide", channels: channels)
  end

  def show(conn, _params) do
    channel = conn.assigns.channel
    user = conn.assigns.current_user

    if user, do: Channels.clear_notification(channel, user)

    redirect(conn, external: url(channel))
  end

  defp maybe_show_nsfw(query, true), do: query
  defp maybe_show_nsfw(query, _falsy), do: where(query, [c], c.nsfw == false)

  defp url(%{type: "LivestreamChannel", short_name: short_name}),
    do: "http://www.livestream.com/#{short_name}"
  defp url(%{type: "PicartoChannel", short_name: short_name}),
    do: "https://picarto.tv/#{short_name}"
  defp url(%{type: "PiczelChannel", short_name: short_name}),
    do: "https://piczel.tv/watch/#{short_name}"
  defp url(%{type: "TwitchChannel", short_name: short_name}),
    do: "https://www.twitch.tv/#{short_name}"
end
