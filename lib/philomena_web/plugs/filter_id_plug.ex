defmodule PhilomenaWeb.FilterIdPlug do
  alias Philomena.Filters.Filter
  alias Philomena.Repo

  # No options
  def init([]), do: false

  def call(conn, _opts) do
    filter = load_filter(conn.params)
    user = conn.assigns.current_user

    case Canada.Can.can?(user, :show, filter) do
      true  -> Plug.Conn.assign(conn, :current_filter, filter)
      false -> conn
    end
  end

  defp load_filter(%{"filter_id" => filter_id}), do: Repo.get(Filter, filter_id)
  defp load_filter(_params), do: nil
end