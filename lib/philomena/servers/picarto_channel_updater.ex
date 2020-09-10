defmodule Philomena.Servers.PicartoChannelUpdater do
  alias Philomena.Channels.Channel
  alias Philomena.Repo
  import Ecto.Query

  @api_online "https://api.picarto.tv/v1/online?adult=true&gaming=true"

  def child_spec([]) do
    %{
      id: Philomena.Servers.PicartoChannelUpdater,
      start: {Philomena.Servers.PicartoChannelUpdater, :start_link, [[]]}
    }
  end

  def start_link([]) do
    {:ok, spawn_link(&run/0)}
  end

  defp run do
    :timer.sleep(:timer.seconds(60))

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    @api_online
    |> Philomena.Http.get()
    |> handle_response(now)

    run()
  end

  defp handle_response({:ok, %Tesla.Env{body: body, status: 200}}, now) do
    resp =
      body
      |> Jason.decode!()
      |> Map.new(&{&1["name"], &1})

    live_channel_names = Map.keys(resp)

    Channel
    |> where([c], c.type == "PicartoChannel" and c.short_name not in ^live_channel_names)
    |> Repo.update_all([set: [is_live: false, updated_at: now]], log: false)

    Channel
    |> where([c], c.type == "PicartoChannel" and c.short_name in ^live_channel_names)
    |> Repo.all(log: false)
    |> Enum.map(&fetch(&1, resp[&1.short_name], now))
  end

  defp handle_response(_response, _now), do: nil

  defp fetch(channel, api_response, now) do
    Channel
    |> where(id: ^channel.id)
    |> Repo.update_all(
      [
        set: [
          title: api_response["title"],
          is_live: true,
          nsfw: api_response["adult"],
          viewers: api_response["viewers"],
          thumbnail_url: api_response["thumbnails"]["web"],
          last_fetched_at: now,
          last_live_at: now,
          description: nil
        ]
      ],
      log: false
    )
  end
end
