defmodule PhilomenaWeb.CurrentFilterPlug do
  @moduledoc """
  Resolves the actor's effective current and forced filters through the Filters
  context, and assigns them to `conn`.
  """

  import Plug.Conn

  alias Philomena.Filters

  def init([]), do: false

  def call(conn, _opts) do
    conn = fetch_cookies(conn)
    cookie_filter_id = conn.cookies["filter_id"]

    {:ok, selection} =
      Filters.load_selected_filters(conn.assigns.actor, cookie_filter_id)

    conn
    |> assign(:current_filter, selection.current_filter)
    |> assign(:forced_filter, selection.forced_filter)
  end
end
