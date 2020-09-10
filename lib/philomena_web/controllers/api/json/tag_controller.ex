defmodule PhilomenaWeb.Api.Json.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => slug}) do
    tag =
      Tag
      |> where(slug: ^slug)
      |> preload([:aliased_tag, :aliases, :implied_tags, :implied_by_tags, :dnp_entries])
      |> Repo.one()

    case tag do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("")

      _ ->
        render(conn, "show.json", tag: tag)
    end
  end
end
