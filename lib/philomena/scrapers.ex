defmodule Philomena.Scrapers do
  @scrapers [
    Philomena.Scrapers.Deviantart,
    Philomena.Scrapers.Twitter,
    #Philomena.Scrapers.Tumblr, # blocked on benoitc/hackney#566
    Philomena.Scrapers.Raw
  ]

  def scrape!(url) do
    uri = URI.parse(url)

    @scrapers
    |> Enum.find(& &1.can_handle?(uri, url))
    |> wrap()
    |> Enum.map(& &1.scrape(uri, url))
    |> unwrap()
  end

  defp wrap(nil), do: []
  defp wrap(res), do: [res]

  defp unwrap([result]), do: result
  defp unwrap(_result), do: nil
end