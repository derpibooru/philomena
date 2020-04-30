defmodule PhilomenaWeb.ApiRequireAuthorizationPlug do
  @moduledoc """
  This plug will force a 401 Unauthorized if no/invalid
  API key provided.

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

    conn
    |> maybe_unauthorized(user)
    |> maybe_forbidden(Bans.exists_for?(user, conn.remote_ip, "NOTAPI"))
  end

  defp maybe_unauthorized(conn, nil) do
    conn
    |> Conn.put_status(:unauthorized)
    |> Controller.text("")
    |> Conn.halt()
  end

  defp maybe_unauthorized(conn, _user), do: conn

  defp maybe_forbidden(conn, nil), do: conn

  defp maybe_forbidden(conn, _current_ban) do
    conn
    |> Conn.put_status(:forbidden)
    |> Controller.text("")
    |> Conn.halt()
  end
end
