defmodule PhilomenaWeb.Image.NavigateController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images.Query
  alias Philomena.ImageNavigator

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def index(conn, %{"rel" => rel} = params) when rel in ~W(prev next) do
    image = conn.assigns.image
    filter = conn.assigns.compiled_filter
    rel = String.to_existing_atom(rel)

    next_image = ImageNavigator.find_consecutive(image, rel, params, compile_query(conn), filter)
    scope = Philomena.ImageScope.scope(conn)

    conn
    |> redirect(to: Routes.image_path(conn, :show, next_image, scope))
  end

  def index(conn, %{"rel" => "find"}) do
    image = conn.assigns.image
    filter = conn.assigns.compiled_filter
    pagination = conn.assigns.pagination

    # Global find does not use the current search scope.
    resp =
      Image.search(
        %{
          query: %{
            bool: %{
              must: %{
                range: %{id: %{gt: image.id}}
              },
              must_not: [
                filter,
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: %{created_at: :desc},
          size: 0
        }
      )

    page_num = page_for_offset(pagination.page_size, resp["hits"]["total"])

    conn
    |> redirect(to: Routes.image_path(conn, :index, page: page_num))
  end

  defp page_for_offset(_per_page, 0), do: 1
  defp page_for_offset(per_page, offset) do
    ((offset + 1) / per_page)
    |> Float.ceil()
    |> trunc()
    |> to_string()
  end

  defp compile_query(conn) do
    user = conn.assigns.current_user

    {:ok, query} = Query.compile(user, match_all_if_blank(conn.params["q"]))

    query
  end

  defp match_all_if_blank(nil), do: "*"
  defp match_all_if_blank(input) do
    case String.trim(input) == "" do
      true  -> "*"
      false -> input
    end
  end
end