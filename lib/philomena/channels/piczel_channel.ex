defmodule Philomena.Channels.PiczelChannel do
  @api_online "https://api.piczel.tv/api/streams"

  @spec live_channels() :: map()
  def live_channels do
    @api_online
    |> PhilomenaProxy.Http.get()
    |> case do
      {:ok, %{body: body, status: 200}} ->
        body
        |> Jason.decode!()
        |> Map.new(&{&1["slug"], fetch(&1)})

      _error ->
        %{}
    end
  end

  defp fetch(api) do
    %{
      title: api["title"],
      is_live: api["live"],
      nsfw: api["adult"],
      viewers: api["viewers"],
      thumbnail_url: api["user"]["avatar"]["avatar"]["url"]
    }
  end
end
