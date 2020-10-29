defmodule Philomena.Channels.PicartoChannel do
  @api_online "https://api.picarto.tv/v1/online?adult=true&gaming=true"

  @spec live_channels(DateTime.t()) :: map()
  def live_channels(now) do
    @api_online
    |> Philomena.Http.get()
    |> case do
      {:ok, %Tesla.Env{body: body, status: 200}} ->
        body
        |> Jason.decode!()
        |> Map.new(&{&1["name"], fetch(&1, now)})

      _error ->
        %{}
    end
  end

  defp fetch(api, now) do
    %{
      title: api["title"],
      is_live: true,
      nsfw: api["adult"],
      viewers: api["viewers"],
      thumbnail_url: api["thumbnails"]["web"],
      last_fetched_at: now,
      last_live_at: now,
      description: nil
    }
  end
end
