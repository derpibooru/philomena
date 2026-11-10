defmodule PhilomenaWeb.FilterIdPlug do
  @moduledoc """
  Loads and authorizes a route's `filter_id` through the Filters context and,
  when visible, assigns it as the current filter.
  """

  alias Philomena.Filters

  # No options
  def init([]), do: false

  def call(conn, _opts) do
    case load_filter(conn.assigns.actor, conn.params) do
      {:ok, filter} -> Plug.Conn.assign(conn, :current_filter, filter)
      {:error, _reason} -> conn
    end
  end

  defp load_filter(actor, %{"filter_id" => filter_id}), do: Filters.show_filter(actor, filter_id)
  defp load_filter(_actor, _params), do: {:error, :not_found}
end
