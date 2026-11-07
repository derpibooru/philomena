defmodule PhilomenaWeb.ApiRequireAuthorizationPlug do
  @moduledoc """
  This plug will force a 401 Unauthorized if no/invalid
  API key provided and a 403 Forbidden if user is banned.

  ## Example

      plug PhilomenaWeb.ApiRequireAuthorizationPlug
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias Philomena.Bans

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    user = conn.assigns.current_user

    cond do
      is_nil(user) -> halt_with(conn, :unauthorized)
      Bans.find(user, conn.remote_ip, "NOTAPI") -> halt_with(conn, :forbidden)
      true -> conn
    end
  end

  defp halt_with(conn, status) do
    conn
    |> Conn.put_status(status)
    |> Controller.text("")
    |> Conn.halt()
  end
end
