defmodule PhilomenaWeb.ActivityController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Elasticsearch

  alias Philomena.{
    Images.Image,
    ImageFeatures.ImageFeature,
    Comments.Comment,
    Channels.Channel,
    Topics.Topic,
    Forums.Forum
  }

  alias Philomena.Interactions
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user

    {:ok, {images, _tags}} =
      ImageLoader.search_string(
        conn,
        "created_at.lte:3 minutes ago",
        pagination: %{conn.assigns.image_pagination | page_number: 1}
      )

    {top_scoring, _tags} =
      ImageLoader.query(
        conn,
        %{range: %{first_seen_at: %{gt: "now-3d"}}},
        sorts: [%{wilson_score: :desc}, %{first_seen_at: :desc}],
        pagination: %{page_number: :rand.uniform(6), page_size: 4}
      )

    comments =
      Elasticsearch.search_records(
        Comment,
        %{
          query: %{
            bool: %{
              must: %{
                range: %{posted_at: %{gt: "now-1w"}}
              },
              must_not: [
                %{terms: %{image_tag_ids: conn.assigns.current_filter.hidden_tag_ids}},
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: %{posted_at: :desc}
        },
        %{page_number: 1, page_size: 6},
        Comment |> preload([:user, image: [:tags]])
      )

    watched =
      if !!user do
        {:ok, {watched_images, _tags}} =
          ImageLoader.search_string(
            conn,
            "my:watched",
            pagination: %{conn.assigns.image_pagination | page_number: 1}
          )

        if Enum.any?(watched_images), do: watched_images
      end

    featured_image =
      Image
      |> join(:inner, [i], f in ImageFeature, on: [image_id: i.id])
      |> filter_hidden(user, conn.params["hidden"])
      |> order_by([i, f], desc: f.created_at)
      |> limit(1)
      |> preload([:tags])
      |> Repo.one()

    streams =
      Channel
      |> where([c], c.nsfw == false)
      |> where([c], not is_nil(c.last_fetched_at))
      |> order_by(desc: :is_live, asc: :title)
      |> limit(6)
      |> Repo.all()

    topics =
      Topic
      |> join(:inner, [t], f in Forum, on: [id: t.forum_id])
      |> where([t, _f], t.hidden_from_users == false)
      |> where([t, _f], fragment("? !~ ?", t.title, "NSFW"))
      |> where([_t, f], f.access_level == "normal")
      |> order_by(desc: :last_replied_to_at)
      |> preload([:forum, last_post: :user])
      |> limit(6)
      |> Repo.all()

    interactions =
      Interactions.user_interactions(
        [images, top_scoring, watched, featured_image],
        user
      )

    render(
      conn,
      "index.html",
      title: "Homepage",
      images: images,
      comments: comments,
      top_scoring: top_scoring,
      watched: watched,
      featured_image: featured_image,
      streams: streams,
      topics: topics,
      interactions: interactions,
      layout_class: "layout--wide"
    )
  end

  def filter_hidden(featured_image, nil, _hidden) do
    featured_image
  end

  def filter_hidden(featured_image, _user, "1") do
    featured_image
  end

  def filter_hidden(featured_image, user, _hidden) do
    featured_image
    |> where(
      [i],
      fragment(
        "NOT EXISTS(SELECT 1 FROM image_hides WHERE image_id = ? AND user_id = ?)",
        i.id,
        ^user.id
      )
    )
  end
end
