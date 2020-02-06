defmodule PhilomenaWeb.EnsureUserEnabledPlug do
  @moduledoc """
  This plug ensures that a user is enabled.

  ## Example

      plug PhilomenaWeb.EnsureUserEnabledPlug
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
    |> disabled?()
    |> maybe_halt(conn)
  end

  defp disabled?(%{deleted_at: deleted_at}) when not is_nil(deleted_at), do: true
  defp disabled?(_user), do: false

  defp maybe_halt(true, conn) do
    conn
    |> Plug.delete()
    |> Controller.redirect(to: Routes.pow_session_path(conn, :new))
  end

  defp maybe_halt(_any, conn), do: conn
end
