defmodule PhilomenaWeb.Image.NavigateController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.ImageNavigator
  alias PhilomenaWeb.ImageScope
  alias Philomena.Elasticsearch
  alias Philomena.Images.Image
  alias Philomena.Images.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def index(conn, %{"rel" => rel}) when rel in ~W(prev next) do
    image = conn.assigns.image
    filter = conn.assigns.compiled_filter
    scope = ImageScope.scope(conn)

    conn
    |> ImageNavigator.find_consecutive(image, compile_query(conn), filter)
    |> case do
      {next_image, hit} ->
        redirect(conn,
          to: Routes.image_path(conn, :show, next_image, Keyword.put(scope, :sort, hit["sort"]))
        )

      nil ->
        redirect(conn, to: Routes.image_path(conn, :show, image, scope))
    end
  end

  def index(conn, %{"rel" => "find"}) do
    pagination = %{conn.assigns.image_pagination | page_number: 1}

    # Find does not use the current search scope
    # (although it probably should).
    body = %{range: %{id: %{gt: conn.assigns.image.id}}}

    {images, _tags} = ImageLoader.query(conn, body, pagination: pagination)
    images = Elasticsearch.search_records(images, Image)

    page_num = page_for_offset(pagination.page_size, images.total_entries)

    redirect(conn, to: Routes.search_path(conn, :index, q: "*", page: page_num))
  end

  defp page_for_offset(per_page, offset) do
    offset
    |> div(per_page)
    |> Kernel.+(1)
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
      true -> "*"
      false -> input
    end
  end
end
