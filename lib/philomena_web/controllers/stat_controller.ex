defmodule PhilomenaWeb.StatController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Topics.Topic
  alias Philomena.Forums.Forum
  alias Philomena.Posts.Post
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    {image_aggs, comment_aggs } = aggregations()
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
      users_24h: users_24h
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

    {forums, last_topic.id - first_topic.id, last_post.id - first_post.id}
  end

  defp users do
    first_user = Repo.one(first(User))
    last_user = Repo.one(last(User))
    time = DateTime.utc_now() |> DateTime.add(-86400, :second)

    last_24h =
      User
      |> where([u], u.created_at > ^time)
      |> Repo.aggregate(:count, :id)

    {last_user.id - first_user.id, last_24h}
  end
end
