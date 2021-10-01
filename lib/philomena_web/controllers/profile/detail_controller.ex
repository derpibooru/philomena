defmodule PhilomenaWeb.Profile.DetailController do
  use PhilomenaWeb, :controller

  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.ModNotes.ModNote
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Polymorphic
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

    mod_notes =
      ModNote
      |> where(notable_type: "User", notable_id: ^user.id)
      |> order_by(desc: :id)
      |> preload(:moderator)
      |> Repo.all()
      |> Polymorphic.load_polymorphic(notable: [notable_id: :notable_type])

    mod_notes =
      mod_notes
      |> MarkdownRenderer.render_collection(conn)
      |> Enum.zip(mod_notes)

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
