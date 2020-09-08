defmodule PhilomenaWeb.PaginationPlug do
  import Plug.Conn

  # No options
  def init([]), do: []

  # Assign pagination info
  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    user = conn.assigns.current_user
    params = conn.params

    page_size = get_page_size(params)
    page_number = get_page_number(params)
    image_page_size = page_size || image_page_size(user)
    comment_page_size = page_size || comment_page_size(user)

    conn
    |> assign(:pagination, %{page_number: page_number, page_size: page_size || 25})
    |> assign(:image_pagination, %{page_number: page_number, page_size: image_page_size})
    |> assign(:scrivener, page: page_number, page_size: page_size || 25)
    |> assign(:comment_scrivener, page: page_number, page_size: comment_page_size)
  end

  defp get_page_number(%{"page" => page}) do
    page
    |> to_integer()
    |> Kernel.||(1)
    |> max(1)
  end

  defp get_page_number(_params), do: 1

  defp get_page_size(%{"per_page" => per_page}) do
    per_page
    |> to_integer()
    |> Kernel.||(25)
    |> max(1)
    |> min(50)
  end

  defp get_page_size(_params), do: nil

  defp to_integer(string) do
    case Integer.parse(string) do
      {int, _rest} -> int
      _ -> nil
    end
  end

  defp image_page_size(%{images_per_page: x}), do: x
  defp image_page_size(_user), do: 15

  defp comment_page_size(%{comments_per_page: x}), do: x
  defp comment_page_size(_user), do: 25
end
