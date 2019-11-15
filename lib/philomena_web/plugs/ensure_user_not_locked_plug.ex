defmodule PhilomenaWeb.Plugs.EnsureUserNotLockedPlug do
  @moduledoc """
  This plug ensures that a user isn't locked.

  ## Example

      plug PhilomenaWeb.Plugs.EnsureUserNotLockedPlug
  """
  alias PhilomenaWeb.Router.Helpers, as: Routes
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Plug

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn
    |> Plug.current_user()
    |> locked?()
    |> maybe_halt(conn)
  end

  defp locked?(%{locked_at: locked_at}) when not is_nil(locked_at), do: true
  defp locked?(_user), do: false

  defp maybe_halt(true, conn) do
    {:ok, conn} = Plug.clear_authenticated_user(conn)

    conn
    |> Controller.put_flash(:error, "Sorry, your account is locked.")
    |> Controller.redirect(to: Routes.pow_session_path(conn, :new))
  end
  defp maybe_halt(_any, conn), do: conn
end