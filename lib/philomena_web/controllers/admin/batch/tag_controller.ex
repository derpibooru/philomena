defmodule PhilomenaWeb.Admin.Batch.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Images
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def update(conn, %{"tags" => tag_list, "image_ids" => image_ids}) do
    tags = Tag.parse_tag_list(tag_list)

    added_tag_names = Enum.reject(tags, &String.starts_with?(&1, "-"))

    removed_tag_names =
      tags
      |> Enum.filter(&String.starts_with?(&1, "-"))
      |> Enum.map(&String.replace_leading(&1, "-", ""))

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
      user_id: attributes[:user].id
    }

    image_ids = Enum.map(image_ids, &String.to_integer/1)

    case Images.batch_update(image_ids, added_tags, removed_tags, attributes) do
      {:ok, _} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:batch_tag_update",
          %{
            image_ids: image_ids,
            added: Enum.map(added_tags, & &1.name),
            removed: Enum.map(removed_tags, & &1.name)
          }
        )

        conn
        |> moderation_log(
          details: &log_details/2,
          data: %{
            tag_list: tag_list,
            image_count: Enum.count(image_ids),
            user: conn.assigns.current_user
          }
        )
        |> json(%{succeeded: image_ids, failed: []})

      _error ->
        json(conn, %{succeeded: [], failed: image_ids})
    end
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :batch_update, Tag) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, data) do
    %{
      body: "Batch tagged '#{data.tag_list}' on #{data.image_count} images",
      subject_path: ~p"/profiles/#{data.user}"
    }
  end
end
