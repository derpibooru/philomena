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
    filters = Filters.recent_and_user_filters(user)
    user = Users.change_user(user)

    conn
    |> Conn.assign(:user_changeset, user)
    |> Conn.assign(:available_filters, filters)
    |> Conn.assign(:spoiler_types, @spoiler_types)
  end
end
