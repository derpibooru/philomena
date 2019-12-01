defmodule PhilomenaWeb.ImageFilterPlug do
  import Plug.Conn
  import Search.String

  alias Philomena.Images.Query
  alias Pow.Plug

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    user = conn |> Plug.current_user()
    filter = conn.assigns[:current_filter]

    tag_exclusion = %{terms: %{tag_ids: filter.hidden_tag_ids}}
    {:ok, query_exclusion} = Query.compile(user, normalize(filter.hidden_complex_str))
    {:ok, query_spoiler} = Query.compile(user, normalize(filter.spoilered_complex_str))

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
end
