defmodule Philomena.Channels.PicartoChannel do
  @api_online "https://api.picarto.tv/api/v1/online?adult=true&gaming=true"

  @spec live_channels() :: map()
  def live_channels do
    @api_online
    |> PhilomenaProxy.Http.get()
    |> case do
      {:ok, %{body: body, status: 200}} ->
        body
        |> JSON.decode!()
        |> Map.new(&{&1["name"], fetch(&1)})

      _error ->
        %{}
    end
  end

  defp fetch(api) do
    %{
      title: api["title"],
      is_live: true,
      nsfw: api["adult"],
      viewers: api["viewers"],
      thumbnail_url: api["thumbnails"]["web"],
      description: nil
    }
  end
end
