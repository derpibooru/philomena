defmodule PhilomenaWeb.FilterIdPlug do
  alias Philomena.Filters.Filter
  alias Philomena.Repo

  # No options
  def init([]), do: false

  def call(conn, _opts) do
    filter = load_filter(conn.params)
    user = conn.assigns.current_user

    if not is_nil(filter) and Canada.Can.can?(user, :show, filter) do
      Plug.Conn.assign(conn, :current_filter, filter)
    else
      conn
    end
  end

  defp load_filter(%{"filter_id" => filter_id}), do: Repo.get(Filter, filter_id)
  defp load_filter(_params), do: nil
end
