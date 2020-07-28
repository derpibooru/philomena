defmodule PhilomenaWeb.EnsureUserEnabledPlug do
  @moduledoc """
  This plug ensures that a user is enabled.

  ## Example

      plug PhilomenaWeb.EnsureUserEnabledPlug
  """

  alias Phoenix.Controller
  alias Plug.Conn
  alias PhilomenaWeb.UserAuth

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn.assigns.current_user
    |> disabled_or_unconfirmed?()
    |> maybe_halt(conn)
  end

  defp disabled_or_unconfirmed?(%{deleted_at: deleted_at}) when not is_nil(deleted_at), do: true
  defp disabled_or_unconfirmed?(%{confirmed_at: nil}), do: true
  defp disabled_or_unconfirmed?(_user), do: false

  defp maybe_halt(true, conn) do
    conn
    |> Controller.put_flash(:error, "Your account is not currently active.")
    |> UserAuth.log_out_user()
    |> Conn.halt()
  end

  defp maybe_halt(_any, conn), do: conn
end
