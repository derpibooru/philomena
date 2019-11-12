defmodule PhilomenaWeb.ProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images, Images.Image, Comments.Comment, Posts.Post, Users.User, Users.Link}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: User, only: :show, id_field: "slug", preload: [awards: :badge, public_links: :tag]

  def show(conn, _params) do
    current_user = conn.assigns.current_user
    filter = conn.assigns.compiled_filter
    user = conn.assigns.user

    {:ok, upload_query} = Images.Query.compile(current_user, "uploader_id:#{user.id}")
    {:ok, fave_query} = Images.Query.compile(current_user, "faved_by_id:#{user.id}")

    recent_uploads =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: filter,
              must: upload_query
            }
          }
        },
        %{page_number: 1, page_size: 6},
        Image |> preload([:tags])
      )

    recent_faves =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must_not: filter,
              must: fave_query
            }
          }
        },
        %{page_number: 1, page_size: 6},
        Image |> preload([:tags])
      )

    render(
      conn,
      "show.html",
      user: user,
      recent_uploads: recent_uploads,
      recent_faves: recent_faves
    )
  end
end
