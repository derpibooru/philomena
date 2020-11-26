defmodule PhilomenaWeb.Admin.ArtistLinkController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, %{"all" => _value}) do
    load_links(ArtistLink, conn)
  end

  def index(conn, %{"q" => query}) do
    query = "%#{query}%"

    ArtistLink
    |> join(:inner, [ul], _ in assoc(ul, :user))
    |> where([ul, u], ilike(u.name, ^query) or ilike(ul.uri, ^query))
    |> load_links(conn)
  end

  def index(conn, _params) do
    ArtistLink
    |> where([u], u.aasm_state in ^["unverified", "link_verified", "contacted"])
    |> load_links(conn)
  end

  defp load_links(queryable, conn) do
    links =
      queryable
      |> order_by(desc: :created_at)
      |> preload([
        :tag,
        :verified_by_user,
        :contacted_by_user,
        user: [:linked_tags, awards: :badge]
      ])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", title: "Admin - Artist Links", artist_links: links)
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, %ArtistLink{}) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
