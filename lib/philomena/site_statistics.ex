defmodule Philomena.SiteStatistics do
  @moduledoc """
  Computes aggregate, sitewide statistics from PostgreSQL and OpenSearch.

  The returned struct is presentation-neutral. Callers decide how and where to
  render it.
  """

  import Ecto.Query, warn: false

  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Item
  alias Philomena.Forums.Forum
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Interaction
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Repo
  alias Philomena.Reports.Report
  alias Philomena.Topics.Topic
  alias Philomena.Users.User
  alias PhilomenaQuery.Search

  @image_aggregation %{
    aggs: %{
      deleted: %{filter: %{term: %{hidden_from_users: true}}},
      non_deleted: %{
        aggs: %{
          all_time: %{date_histogram: %{field: "created_at", calendar_interval: "day"}},
          avg_comments: %{avg: %{field: "comment_count"}},
          faves_gt_0: %{filter: %{range: %{faves: %{gt: 0}}}},
          last_24h: %{filter: %{range: %{created_at: %{gt: "now-24h"}}}},
          score_gt_0: %{filter: %{range: %{score: %{gt: 0}}}},
          score_lt_0: %{filter: %{range: %{score: %{lt: 0}}}}
        },
        filter: %{term: %{hidden_from_users: false}}
      }
    }
  }

  @comment_aggregation %{
    aggs: %{
      deleted: %{filter: %{term: %{hidden_from_users: true}}},
      last_24h: %{filter: %{range: %{created_at: %{gt: "now-24h"}}}}
    },
    track_total_hits: true
  }

  @enforce_keys [
    :image_aggs,
    :comment_aggs,
    :forums_count,
    :topics_count,
    :posts_count,
    :users_count,
    :users_24h,
    :open_commissions,
    :commission_items,
    :open_reports,
    :report_stat_count,
    :response_time,
    :gallery_count,
    :gallery_size,
    :distinct_creators,
    :images_in_galleries
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          image_aggs: map(),
          comment_aggs: map(),
          forums_count: non_neg_integer(),
          topics_count: non_neg_integer(),
          posts_count: non_neg_integer(),
          users_count: non_neg_integer(),
          users_24h: non_neg_integer(),
          open_commissions: non_neg_integer(),
          commission_items: non_neg_integer(),
          open_reports: non_neg_integer(),
          report_stat_count: non_neg_integer(),
          response_time: non_neg_integer(),
          gallery_count: non_neg_integer(),
          gallery_size: non_neg_integer(),
          distinct_creators: non_neg_integer(),
          images_in_galleries: non_neg_integer()
        }

  @doc """
  Computes a current snapshot of aggregate site statistics.

  ## Examples

      iex> snapshot = calculate()

  """
  @spec calculate() :: t()
  def calculate do
    {gallery_count, gallery_size, distinct_creators, images_in_galleries} = galleries()
    {open_reports, report_count, response_time} = moderation()
    {open_commissions, commission_items} = commissions()
    {image_aggs, comment_aggs} = aggregations()
    {forums, topics, posts} = forums()
    {users, users_24h} = users()

    %__MODULE__{
      image_aggs: image_aggs,
      comment_aggs: comment_aggs,
      forums_count: forums,
      topics_count: topics,
      posts_count: posts,
      users_count: users,
      users_24h: users_24h,
      open_commissions: open_commissions,
      commission_items: commission_items,
      open_reports: open_reports,
      report_stat_count: report_count,
      response_time: response_time,
      gallery_count: gallery_count,
      gallery_size: gallery_size,
      distinct_creators: distinct_creators,
      images_in_galleries: images_in_galleries
    }
  end

  defp aggregations do
    {
      Search.search(Image, @image_aggregation),
      Search.search(Comment, @comment_aggregation)
    }
  end

  defp forums do
    forums =
      Forum
      |> where(access_level: "normal")
      |> Repo.aggregate(:count, :id)

    first_topic = Repo.one(first(Topic))
    last_topic = Repo.one(last(Topic))
    first_post = Repo.one(first(Post))
    last_post = Repo.one(last(Post))

    {forums, id_span(last_topic, first_topic), id_span(last_post, first_post)}
  end

  defp users do
    total = Repo.aggregate(User, :count, :id)

    last_24h =
      User
      |> where([user], user.created_at > ago(1, "day"))
      |> Repo.aggregate(:count, :id)

    {total, last_24h}
  end

  defp galleries do
    gallery_count = Repo.aggregate(Gallery, :count, :id)

    gallery_size =
      Gallery
      |> Repo.aggregate(:avg, :image_count)
      |> Kernel.||(Decimal.new(0))
      |> Decimal.to_float()
      |> trunc()

    distinct_creators =
      Gallery
      |> distinct(:user_id)
      |> Repo.aggregate(:count, :id)

    first_interaction = Repo.one(first(Interaction))
    last_interaction = Repo.one(last(Interaction))

    {gallery_count, gallery_size, distinct_creators, id_span(last_interaction, first_interaction)}
  end

  defp commissions do
    open_commissions = Repo.aggregate(where(Commission, open: true), :count, :id)
    commission_items = Repo.aggregate(Item, :count, :id)

    {open_commissions, commission_items}
  end

  defp moderation do
    open_reports = Repo.aggregate(where(Report, open: true), :count, :id)
    first_report = Repo.one(first(Report))
    last_report = Repo.one(last(Report))

    closed_reports =
      Report
      |> where(open: false)
      |> order_by(desc: :created_at)
      |> limit(250)
      |> Repo.all()

    response_time =
      closed_reports
      |> Enum.reduce(0, &(&2 + DateTime.diff(&1.updated_at, &1.created_at, :second)))
      |> Kernel./(max(length(closed_reports), 1) * 3600)
      |> trunc()

    {open_reports, id_span(last_report, first_report), response_time}
  end

  defp id_span(nil, nil), do: 0
  defp id_span(%{id: last_id}, %{id: first_id}), do: last_id - first_id
end
