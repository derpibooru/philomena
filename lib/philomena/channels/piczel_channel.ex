defmodule Philomena.Channels.PiczelChannel do
  @api_online "https://api.piczel.tv/api/streams"

  @spec live_channels(DateTime.t()) :: map()
  def live_channels(now) do
    @api_online
    |> Philomena.Http.get()
    |> case do
      {:ok, %Tesla.Env{body: body, status: 200}} ->
        body
        |> Jason.decode!()
        |> Map.new(&{&1["slug"], fetch(&1, now)})

      _error ->
        %{}
    end
  end

  defp fetch(api, now) do
    %{
      title: api["title"],
      is_live: api["live"],
      nsfw: api["adult"],
      viewers: api["viewers"],
      thumbnail_url: api["user"]["avatar"]["avatar"]["url"],
      last_fetched_at: now,
      last_live_at: now
    }
  end
end
