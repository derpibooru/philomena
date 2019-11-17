defmodule PhilomenaWeb.ActivityController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, ImageFeatures.ImageFeature, Comments.Comment, Channels.Channel, Topics.Topic, Forums.Forum}
  alias Philomena.Interactions
  alias Philomena.Images
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user
    filter = conn.assigns.compiled_filter
    {:ok, image_query} = Images.Query.compile(user, "created_at.lte:3 minutes ago")

    images =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must: image_query,
              must_not: [
                filter,
                %{term: %{hidden_from_users: true}}
              ],
            }
          },
          sort: %{created_at: :desc}
        },
        %{page_number: 1, page_size: 25},
        Image |> preload([:tags])
      )

    top_scoring =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must: %{range: %{first_seen_at: %{gt: "now-3d"}}},
              must_not: [
                filter,
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: [%{score: :desc}, %{first_seen_at: :desc}]
        },
        %{page_number: :rand.uniform(6), page_size: 4},
        Image |> preload([:tags])
      )

    comments =
      Comment.search_records(
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

    watched = if !!user do
      {:ok, watched_query} = Images.Query.compile(user, "my:watched")

      Image.search_records(
        %{
          query: %{
            bool: %{
              must: watched_query,
              must_not: [
                filter,
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: %{created_at: :desc}
        },
        %{page_number: 1, page_size: 25},
        Image |> preload([:tags])
      )
    end

    featured_image =
      Image
      |> join(:inner, [i], f in ImageFeature, on: [image_id: i.id])
      |> order_by([i, f], desc: f.created_at)
      |> limit(1)
      |> preload([:tags])
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

    interactions =
      Interactions.user_interactions(
        [images, top_scoring, watched, featured_image],
        user
      )

    render(
      conn,
      "index.html",
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
end
