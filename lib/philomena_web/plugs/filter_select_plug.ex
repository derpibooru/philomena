defmodule PhilomenaWeb.FilterSelectPlug do
  @moduledoc """
  This plug sets up the filter menu for the layout if there is a
  user currently signed in.

  ## Example

      plug PhilomenaWeb.FilterSelectPlug
  """

  alias Philomena.Filters
  alias Philomena.Users
  alias Plug.Conn

  @spoiler_types %{
    "Spoilers" => [
      static: "static",
      click: "click",
      hover: "hover",
      off: "off"
    ]
  }

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    maybe_assign_filters(conn, conn.assigns.current_user)
  end

  defp maybe_assign_filters(conn, nil), do: conn

  defp maybe_assign_filters(conn, user) do
    {:ok, filter_selection} = Filters.recent_and_user_filters(conn.assigns.actor)

    conn
    |> Conn.assign(:user_changeset, Users.filter_selection_changeset(user))
    |> Conn.assign(:spoiler_changeset, Users.spoiler_type_changeset(user))
    |> Conn.assign(:available_filters, filter_select_options(filter_selection))
    |> Conn.assign(:spoiler_types, @spoiler_types)
  end

  defp filter_select_options(%{recent_filters: recent_filters, user_filters: user_filters}) do
    [
      {"Your Filters", filter_options(user_filters)},
      {"Recent Filters", filter_options(recent_filters)}
    ]
    |> Enum.reject(fn {_label, options} -> options == [] end)
  end

  defp filter_options(filters) do
    Enum.map(filters, &[key: &1.name, value: &1.id])
  end
end
