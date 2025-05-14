defmodule PhilomenaWeb.Profile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.TagChanges

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_resource, model: User, id_name: "profile_id", id_field: "slug", persisted: true

  def index(conn, params) do
    user = conn.assigns.user

    {tag_changes, image_count} =
      TagChanges.load(
        %{
          field: :user_id,
          value: user.id,
          added: params["added"],
          tag: params["only_tag"],
          filter_anon: true
        },
        :image_id,
        conn.assigns.scrivener
      )

    # params.permit(:added, :only_tag) ...
    pagination_params =
      [added: conn.params["added"], only_tag: conn.params["only_tag"]]
      |> Keyword.filter(fn {_k, v} -> not is_nil(v) and v != "" end)

    render(conn, "index.html",
      title: "Tag Changes for User `#{user.name}'",
      user: user,
      tag_changes: tag_changes,
      pagination_params: pagination_params,
      image_count: image_count
    )
  end
end
