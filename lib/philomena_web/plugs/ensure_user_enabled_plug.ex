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
    if locked_out?(conn.assigns.current_user, conn.path_info) do
      halt_disabled(conn, conn.path_info)
    else
      conn
    end
  end

  # Deactivated accounts are locked out everywhere.
  defp locked_out?(%{deleted_at: deleted_at}, _path_info) when not is_nil(deleted_at), do: true

  # Unconfirmed accounts are locked out everywhere except their own
  # confirmation link, which must be reachable so that a user still logged in
  # from registration can actually confirm the account.
  defp locked_out?(%{confirmed_at: nil}, path_info), do: not confirmation_show_path?(path_info)

  defp locked_out?(_user, _path_info), do: false

  # `GET /confirmations/:token`. `/confirmations/new` (the resend-email form)
  # is deliberately excluded so its logout behavior is unchanged.
  defp confirmation_show_path?(["confirmations", "new"]), do: false
  defp confirmation_show_path?(["confirmations", _token]), do: true
  defp confirmation_show_path?(_path_info), do: false

  # The `:api` pipeline fetches neither session nor flash, and there is no
  # session to log out of - the caller authenticated with a key.
  defp halt_disabled(conn, ["api" | _]) do
    conn
    |> Conn.put_status(:forbidden)
    |> Controller.text("")
    |> Conn.halt()
  end

  defp halt_disabled(conn, _path_info) do
    conn
    |> Controller.put_flash(:error, "Your account is not currently active.")
    |> UserAuth.log_out_user()
    |> Conn.halt()
  end
end
