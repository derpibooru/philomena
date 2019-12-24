defmodule PhilomenaWeb.Api.Json.TagController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TagJson
  alias Philomena.Tags.Tag

  plug PhilomenaWeb.RecodeParameterPlug, [name: "id"] when action in [:show]
  plug :load_resource, model: Tag, id_field: "slug", persisted: true, preload: [:aliased_tag, :aliases, :implied_tags, :implied_by_tags, :dnp_entries]

  def show(conn, _params) do
    json(conn, %{tag: TagJson.as_json(conn.assigns.tag)})
  end
end