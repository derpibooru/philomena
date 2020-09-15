defmodule PhilomenaWeb.CurrentFilterPlug do
  import Plug.Conn

  alias Philomena.{Filters, Filters.Filter, Users.User}
  alias Philomena.Repo

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    conn = fetch_cookies(conn)
    user = conn.assigns.current_user

    {filter, forced_filter} =
      if user do
        user =
          user
          |> Repo.preload([:current_filter, :forced_filter])
          |> maybe_set_default_filter()

        {user.current_filter, user.forced_filter}
      else
        filter = load_and_authorize_filter(conn.cookies, user)

        {filter || Filters.default_filter(), nil}
      end

    conn
    |> assign(:current_filter, filter)
    |> assign(:forced_filter, forced_filter)
  end

  defp maybe_set_default_filter(%{current_filter: nil} = user) do
    filter = Filters.default_filter()

    {:ok, user} =
      user
      |> User.filter_changeset(filter)
      |> Repo.update()

    Map.put(user, :current_filter, filter)
  end

  defp maybe_set_default_filter(user), do: user

  defp load_and_authorize_filter(%{"filter_id" => filter_id}, user) do
    Filter
    |> Repo.get(filter_id)
    |> case do
      nil ->
        nil

      filter ->
        case Canada.Can.can?(user, :show, filter) do
          true -> filter
          false -> nil
        end
    end
  end

  defp load_and_authorize_filter(_cookies, _user) do
    nil
  end
end
