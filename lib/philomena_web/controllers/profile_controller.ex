defmodule PhilomenaWeb.ProfileController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Textile.Renderer
  alias Philomena.Users.User
  alias Philomena.Galleries.Gallery
  alias Philomena.Posts.Post
  alias Philomena.Comments.Comment
  alias Philomena.Interactions
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: User, only: :show, id_field: "slug", preload: [awards: :badge, public_links: :tag]

  def show(conn, _params) do
    current_user = conn.assigns.current_user
    user = conn.assigns.user

    {:ok, recent_uploads} =
      ImageLoader.search_string(
        conn,
        "uploader_id:#{user.id}",
        pagination: %{page_number: 1, page_size: 6}
      )

    {:ok, recent_faves} =
      ImageLoader.search_string(
        conn,
        "faved_by_id:#{user.id}",
        pagination: %{page_number: 1, page_size: 6}
      )

    recent_comments =
      Comment.search_records(
        %{
          query: %{
            bool: %{
              must: [
                %{term: %{user_id: user.id}},
                %{term: %{anonymous: false}},
                %{term: %{hidden_from_users: false}}
              ]
            }
          },
          sort: %{posted_at: :desc}
        },
        %{page_size: 3},
        Comment |> preload(user: [awards: :badge], image: :tags)
      )
      |> Enum.filter(&Canada.Can.can?(current_user, :show, &1.image))

    recent_comments =
      recent_comments
      |> Renderer.render_collection(conn)
      |> Enum.zip(recent_comments)

    recent_posts =
      Post.search_records(
        %{
          query: %{
            bool: %{
              must: [
                %{term: %{user_id: user.id}},
                %{term: %{anonymous: false}},
                %{term: %{hidden_from_users: false}},
                %{term: %{access_level: "normal"}}
              ]
            }
          },
          sort: %{created_at: :desc}
        },
        %{page_size: 6},
        Post |> preload(user: [awards: :badge], topic: :forum)
      )
      |> Enum.filter(&Canada.Can.can?(current_user, :show, &1.topic))

    recent_galleries =
      Gallery
      |> where(creator_id: ^user.id)
      |> preload([:creator, thumbnail: :tags])
      |> limit(5)
      |> Repo.all()

    interactions =
      Interactions.user_interactions([recent_uploads, recent_faves], current_user)

    render(
      conn,
      "show.html",
      user: user,
      interactions: interactions,
      recent_uploads: recent_uploads,
      recent_faves: recent_faves,
      recent_comments: recent_comments,
      recent_posts: recent_posts,
      recent_galleries: recent_galleries,
      layout_class: "layout--wide"
    )
  end
end
