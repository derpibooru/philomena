defmodule Philomena.SiteStatisticsTest do
  use Philomena.DataCase, async: false

  @moduletag :search

  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.SiteStatistics
  alias Philomena.StaticPages.StaticPage
  alias Philomena.Repo
  alias PhilomenaQuery.Search
  alias PhilomenaWeb.StatsUpdater

  setup do
    Search.clear_index!(Image)
    Search.clear_index!(Comment)
    :ok
  end

  test "calculates an empty sitewide snapshot" do
    assert %SiteStatistics{} = statistics = SiteStatistics.calculate()

    assert statistics.forums_count == 0
    assert statistics.topics_count == 0
    assert statistics.posts_count == 0
    assert statistics.users_count == 0
    assert statistics.users_24h == 0
    assert statistics.open_commissions == 0
    assert statistics.commission_items == 0
    assert statistics.open_reports == 0
    assert statistics.report_stat_count == 0
    assert statistics.response_time == 0
    assert statistics.gallery_count == 0
    assert statistics.gallery_size == 0
    assert statistics.distinct_creators == 0
    assert statistics.images_in_galleries == 0
    assert statistics.image_aggs["aggregations"]["non_deleted"]["doc_count"] == 0
    assert statistics.comment_aggs["hits"]["total"]["value"] == 0
  end

  test "the web updater renders and persists the domain snapshot" do
    assert {1, nil} = StatsUpdater.update_stats!()

    page = Repo.get_by!(StaticPage, slug: "stats")
    assert page.title == "Statistics"
    assert page.body =~ "There are"
    assert page.body =~ "non-deleted images"
  end
end
