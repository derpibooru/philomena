defmodule PhilomenaWeb.Plugs.CurrentFilter do
  import Plug.Conn
  import Ecto.Query

  alias Philomena.Filters
  alias Pow.Plug

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    user = conn |> Plug.current_user()

    filter =
      if user do
        user = user |> preload(:current_filter)
        user.current_filter
      else
        Filters.default_filter()
      end

    conn
    |> assign(:current_filter, filter)
  end
end
