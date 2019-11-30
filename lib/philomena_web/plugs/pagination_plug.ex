defmodule PhilomenaWeb.PaginationPlug do
  import Plug.Conn
  alias Pow.Plug

  # No options
  def init([]), do: []

  # Assign pagination info
  def call(conn, _opts) do
    conn = conn |> fetch_query_params()
    user = conn |> Plug.current_user()
    params = conn.params

    page_number =
      case Integer.parse(params["page"] |> to_string()) do
        {int, _rest} ->
          int
        _ ->
          1
      end

    page_number = page_number |> max(1)

    page_size =
      case Integer.parse(params["per_page"] |> to_string()) do
        {int, _rest} ->
          int
        _ ->
          25
      end

    page_size = page_size |> max(1) |> min(50)

    conn
    |> assign(:pagination, %{page_number: page_number, page_size: page_size})
    |> assign(:image_pagination, %{page_number: page_number, page_size: image_page_size(user)})
    |> assign(:scrivener, [page: page_number, page_size: page_size])
    |> assign(:comment_scrivener, [page: page_number, page_size: comment_page_size(user)])
  end

  defp image_page_size(%{images_per_page: x}), do: x
  defp image_page_size(_user), do: 15

  defp comment_page_size(%{comments_per_page: x}), do: x
  defp comment_page_size(_user), do: 25
end
