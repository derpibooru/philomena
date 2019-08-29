defmodule PhilomenaWeb.Plugs.ImageFilter do
  import Plug.Conn

  alias Philomena.Images.Query
  alias Pow.Plug

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    user = conn |> Plug.current_user()
    filter = conn.assigns[:current_filter]

    tag_exclusion = %{terms: %{tag_ids: filter.hidden_tag_ids}}
    {:ok, query_exclusion} = Query.compile(user, filter.hidden_complex_str)

    query = %{
      bool: %{
        should: [tag_exclusion, query_exclusion]
      }
    }

    conn
    |> assign(:compiled_filter, query)
  end
end
