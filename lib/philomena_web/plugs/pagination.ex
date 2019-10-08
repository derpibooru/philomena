defmodule PhilomenaWeb.Plugs.Pagination do
  import Plug.Conn

  # No options
  def init([]), do: false

  # Assign pagination info
  def call(conn, _opts) do
    conn = conn |> fetch_query_params()
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
    |> assign(:scrivener, [page: page_number, page_size: page_size])
  end
end
