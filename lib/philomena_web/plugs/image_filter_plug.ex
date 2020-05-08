defmodule PhilomenaWeb.ImageFilterPlug do
  import Plug.Conn
  import Philomena.Search.String

  alias Philomena.Images.Query
  alias Pow.Plug

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    user = conn |> Plug.current_user()
    filter = conn.assigns[:current_filter]

    tag_exclusion = %{terms: %{tag_ids: filter.hidden_tag_ids}}
    query_exclusion = invalid_filter_guard(user, filter.hidden_complex_str)
    query_spoiler = invalid_filter_guard(user, filter.spoilered_complex_str)

    query = %{
      bool: %{
        should: [tag_exclusion, query_exclusion]
      }
    }

    conn
    |> assign(:compiled_complex_filter, query_exclusion)
    |> assign(:compiled_complex_spoiler, query_spoiler)
    |> assign(:compiled_filter, query)
  end

  defp invalid_filter_guard(user, search_string) do
    case Query.compile(user, normalize(search_string)) do
      {:ok, query} -> query
      _error -> %{match_all: %{}}
    end
  end
end
