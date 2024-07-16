defmodule PhilomenaWeb.Profile.DetailController do
  use PhilomenaWeb, :controller

  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.ModNotes
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show_details

  plug :load_and_authorize_resource,
    model: User,
    id_field: "slug",
    id_name: "profile_id",
    persisted: true

  def index(conn, _params) do
    user = conn.assigns.user

    renderer = &MarkdownRenderer.render_collection(&1, conn)
    mod_notes = ModNotes.list_all_mod_notes_by_type_and_id("User", user.id, renderer)

    name_changes =
      UserNameChange
      |> where(user_id: ^user.id)
      |> order_by(desc: :id)
      |> Repo.all()

    render(conn, "index.html",
      title: "Profile Details for User `#{user.name}'",
      mod_notes: mod_notes,
      name_changes: name_changes
    )
  end
end
