defmodule PowMultiFactor.Phoenix.ControllerCallbacks do
  @moduledoc """
  Controller callback logic for multi-factor authentication.

  ### 2FA code not submitted

  Triggers on `Pow.Phoenix.SessionController.create/2`.

  When a user with 2FA enabled attempts to sign in without submitting their
  TOTP token, the session will be cleared, and the user redirected back to
  `Pow.Phoenix.Routes.session_path/1`.

  ### User updates account

  Triggers on `Pow.Phoenix.RegistrationController.update/2`

  When a user changes their account settings, they are required to confirm a
  current 2FA token.

  See `PowMultiFactor.Ecto.Schema` for more.
  """

  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Pow.Plug
  alias PowMultiFactor.Plug, as: PowMultiFactorPlug

  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, config) do
    return_path = routes(conn).session_path(conn, :new)

    clear_unauthorized(conn, config, {:ok, conn}, return_path)
  end

  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, config) do
    return_path = routes(conn).registration_path(conn, :edit)

    halt_unauthorized(conn, config, {:ok, user, conn}, return_path)
  end

  defp clear_unauthorized(conn, config, success_response, return_path) do
    case PowMultiFactorPlug.mfa_authorized?(conn, config) do
      false -> clear_auth(conn) |> go_back(return_path)
      true  -> success_response
    end
  end

  defp halt_unauthorized(conn, config, success_response, return_path) do
    case PowMultiFactorPlug.mfa_authorized?(conn, config) do
      false -> go_back(conn, return_path)
      true  -> success_response
    end
  end

  def clear_auth(conn) do
    {:ok, conn} = Plug.clear_authenticated_user(conn)

    conn
  end

  defp go_back(conn, return_path) do
    error = extension_messages(conn).invalid_multi_factor(conn)
    conn  =
      conn
      |> Phoenix.Controller.put_flash(:error, error)
      |> Phoenix.Controller.redirect(to: return_path)

    {:halt, conn}
  end
end
