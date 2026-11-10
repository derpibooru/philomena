defmodule PhilomenaWeb.StatsUpdater do
  alias Philomena.SiteStatistics
  alias Philomena.StaticPages

  def update_stats! do
    body =
      SiteStatistics.calculate()
      |> Map.from_struct()
      |> Map.to_list()
      |> then(&Phoenix.View.render(PhilomenaWeb.StatView, "index.html", &1))
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    StaticPages.upsert_statistics_page(body)
  end
end
