defmodule PowCaptcha.Phoenix.ControllerCallbacks do
  @moduledoc """
  Controller callback logic for captcha verification.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Pow.Config
  alias Plug.Conn
  alias Phoenix.Controller

  alias PowResetPassword.Phoenix.ResetPasswordController

  @doc false
  @impl true
  def before_process(ResetPasswordController, :create, conn, config) do
    verifier = Config.get(config, :captcha_verifier)
    return_path = routes(conn).path_for(conn, ResetPasswordController, :new)

    verifier.valid_solution?(conn.params)
    |> maybe_halt(conn, return_path)
  end

  defp maybe_halt(false, conn, return_path) do
    conn
    |> Controller.put_flash(
      :error,
      "There was an error verifying you're not a robot. Please try again."
    )
    |> Controller.redirect(to: return_path)
    |> Conn.halt()
  end

  defp maybe_halt(true, conn, _return_path) do
    conn
  end
end
