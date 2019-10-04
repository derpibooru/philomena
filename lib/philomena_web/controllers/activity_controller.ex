defmodule PhilomenaWeb.ActivityController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images, Images.Image, Images.Feature, Channels.Channel, Topics.Topic, Forums.Forum}
  alias Philomena.Repo
  import Ecto.Query

  plug ImageFilter

  def index(conn, _params) do
    user = conn.assigns.current_user
    filter = conn.assigns.compiled_filter
    {:ok, image_query} = Images.Query.compile(user, "created_at.lte:3 minutes ago")

    images =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: filter,
              must: image_query
            }
          },
          size: 25,
          sort: %{created_at: :desc}
        },
        Image |> preload([:tags])
      )

    top_scoring =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: filter,
              must: %{range: %{first_seen_at: %{gt: "now-3d"}}}
            }
          },
          size: 4,
          from: :rand.uniform(26) - 1,
          sort: [%{score: :desc}, %{first_seen_at: :desc}]
        },
        Image |> preload([:tags])
      )

    watched = if !!user do
      {:ok, watched_query} = Images.Query.compile(user, "my:watched")

      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: filter,
              must: watched_query
            }
          },
          size: 25,
          sort: %{created_at: :desc}
        },
        Image |> preload([:tags])
      )
    end

    featured_image =
      Image
      |> join(:inner, [i], f in Feature, on: [id: i.image_id])
      |> order_by([i, f], desc: f.created_at)
      |> limit(1)
      |> Repo.one()

    streams =
      Channel
      |> where([c], c.nsfw  == false)
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

    render(
      conn,
      "index.html",
      images: images,
      top_scoring: top_scoring,
      watched: watched,
      featured_image: featured_image,
      streams: streams,
      topics: topics
    )
  end
end
