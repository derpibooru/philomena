defmodule PhilomenaWeb.CurrentFilterPlug do
  import Plug.Conn

  alias Philomena.{Filters, Filters.Filter, Users.User}
  alias Philomena.Repo

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    conn = fetch_session(conn)
    user = conn.assigns.current_user

    {filter, forced_filter} =
      if user do
        user =
          user
          |> Repo.preload([:current_filter, :forced_filter])
          |> maybe_set_default_filter()

        {user.current_filter, user.forced_filter}
      else
        filter_id = conn |> get_session(:filter_id)

        filter = if filter_id, do: Repo.get(Filter, filter_id)

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
end
