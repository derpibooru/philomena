defmodule PhilomenaWeb.StatController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Topics.Topic
  alias Philomena.Forums.Forum
  alias Philomena.Posts.Post
  alias Philomena.Users.User
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Interaction
  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Item
  alias Philomena.Reports.Report
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    {gallery_count, gallery_size, distinct_creators, images_in_galleries} = galleries()
    {open_reports, report_count, response_time} = moderation()
    {open_commissions, commission_items} = commissions()
    {image_aggs, comment_aggs} = aggregations()
    {forums, topics, posts} = forums()
    {users, users_24h} = users()

    render(
      conn,
      "index.html",
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
      report_count: report_count,
      response_time: response_time,
      gallery_count: gallery_count,
      gallery_size: gallery_size,
      distinct_creators: distinct_creators,
      images_in_galleries: images_in_galleries
    )
  end

  defp aggregations do
    data =
      Application.get_env(:philomena, :aggregation_json)
      |> Jason.decode!()

    {Image.search(data["images"]), Comment.search(data["comments"])}
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

    {forums, diff(last_topic, first_topic), diff(last_post, first_post)}
  end

  defp users do
    first_user = Repo.one(first(User))
    last_user = Repo.one(last(User))
    time = DateTime.utc_now() |> DateTime.add(-86400, :second)

    last_24h =
      User
      |> where([u], u.created_at > ^time)
      |> Repo.aggregate(:count, :id)

    {diff(last_user, first_user), last_24h}
  end

  defp galleries do
    gallery_count = Repo.aggregate(Gallery, :count, :id)

    gallery_size =
      Repo.aggregate(Gallery, :avg, :image_count)
      |> Kernel.||(Decimal.new(0))
      |> Decimal.to_float()
      |> trunc()

    distinct_creators =
      Gallery
      |> distinct(:creator_id)
      |> Repo.aggregate(:count, :id)

    first_gi = Repo.one(first(Interaction))
    last_gi = Repo.one(last(Interaction))

    {gallery_count, gallery_size, distinct_creators, diff(last_gi, first_gi)}
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
      |> Enum.reduce(0, & &2 + NaiveDateTime.diff(&1.updated_at, &1.created_at, :second))
      |> Kernel./(safe_length(closed_reports) * 3600)
      |> trunc()

    {open_reports, diff(last_report, first_report), response_time}
  end

  defp diff(nil, nil), do: 0
  defp diff(%{id: id2}, %{id: id1}), do: id2 - id1

  defp safe_length([]), do: 1
  defp safe_length(list), do: length(list)
end
