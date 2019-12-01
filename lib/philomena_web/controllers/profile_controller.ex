defmodule PhilomenaWeb.ProfileController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Users.User
  alias Philomena.Interactions

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

    interactions =
      Interactions.user_interactions([recent_uploads, recent_faves], current_user)

    render(
      conn,
      "show.html",
      user: user,
      interactions: interactions,
      recent_uploads: recent_uploads,
      recent_faves: recent_faves,
      layout_class: "layout--wide"
    )
  end
end
