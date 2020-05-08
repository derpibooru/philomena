defmodule PhilomenaWeb.Admin.Batch.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Images
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def update(conn, %{"tags" => tags, "image_ids" => image_ids}) do
    tags = Tag.parse_tag_list(tags)

    added_tag_names = Enum.reject(tags, &String.starts_with?(&1, "-"))

    removed_tag_names =
      tags
      |> Enum.filter(&String.starts_with?(&1, "-"))
      |> Enum.map(&String.slice(&1, 1..-1))

    added_tags =
      Tag
      |> where([t], t.name in ^added_tag_names)
      |> preload([:implied_tags, aliased_tag: :implied_tags])
      |> Repo.all()
      |> Enum.map(&(&1.aliased_tag || &1))
      |> Enum.flat_map(&[&1 | &1.implied_tags])

    removed_tags =
      Tag
      |> where([t], t.name in ^removed_tag_names)
      |> Repo.all()

    attributes = conn.assigns.attributes

    attributes = %{
      ip: attributes[:ip],
      fingerprint: attributes[:fingerprint],
      user_agent: attributes[:user_agent],
      referrer: attributes[:referrer],
      user_id: attributes[:user].id
    }

    image_ids = Enum.map(image_ids, &String.to_integer/1)

    case Images.batch_update(image_ids, added_tags, removed_tags, attributes) do
      {:ok, _} ->
        json(conn, %{succeeded: image_ids, failed: []})

      _error ->
        json(conn, %{succeeded: [], failed: image_ids})
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :batch_update, Tag) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
