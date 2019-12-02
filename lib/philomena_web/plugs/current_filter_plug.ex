defmodule PhilomenaWeb.CurrentFilterPlug do
  import Plug.Conn

  alias Philomena.{Filters, Filters.Filter, Users.User}
  alias Philomena.Repo
  alias Pow.Plug
  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    conn = conn |> fetch_session()
    user = conn |> Plug.current_user()

    filter =
      if user do
        user
        |> Repo.preload(:current_filter)
        |> maybe_set_default_filter()
        |> Map.get(:current_filter)
      else
        filter_id = conn |> get_session(:filter_id)

        filter = if filter_id, do: Repo.get(Filter, filter_id) 

        filter || Filters.default_filter()
      end

    conn
    |> assign(:current_filter, filter)
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
