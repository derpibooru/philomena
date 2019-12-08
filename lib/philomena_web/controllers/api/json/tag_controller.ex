defmodule PhilomenaWeb.Api.Json.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag

  plug PhilomenaWeb.RecodeParameterPlug, [name: "id"] when action in [:show]
  plug :load_resource, model: Tag, id_field: "slug", persisted: true, preload: [:aliased_tag, :aliases, :implied_tags, :implied_by_tags, :dnp_entries]

  def show(conn, _params) do
    json(conn, %{tag: tag_json(conn.assigns.tag)})
  end

  defp tag_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      slug: tag.slug,
      description: tag.description,
      short_description: tag.short_description,
      images: tag.images_count,
      spoiler_image_uri: tag_image(tag),
      namespace: tag.namespace,
      name_in_namespace: tag.name_in_namespace,
      category: tag.category,
      aliased_tag: aliased_tag(tag),
      aliases: Enum.map(tag.aliases, & &1.slug),
      implied_tags: Enum.map(tag.implied_tags, & &1.slug),
      implied_by_tags: Enum.map(tag.implied_by_tags, & &1.slug),
      dnp_entries: Enum.map(tag.dnp_entries, &%{conditions: &1.conditions})
    }
  end

  defp aliased_tag(%{aliased_tag: nil}), do: nil
  defp aliased_tag(%{aliased_tag: t}), do: t.slug

  # TODO: copied from Tag.Fetch
  defp tag_image(%{image: image}) when image not in [nil, ""],
    do: tag_url_root() <> "/" <> image
  defp tag_image(_other),
    do: nil

  defp tag_url_root do
    Application.get_env(:philomena, :tag_url_root)
  end
end