defmodule PhilomenaWeb.HaltTotp.Phoenix.ControllerCallbacks do
  use Pow.Extension.Phoenix.ControllerCallbacks.Base
  alias Pow.Plug
  import Phoenix.Controller

  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    conn
    |> Plug.current_user()
    |> halt_totp(conn)
  end

  defp halt_totp(%{otp_required_for_login: true}, conn) do
    {:ok, conn} = Plug.clear_authenticated_user(conn)

    conn =
      conn
      |> put_flash(:error, "Cannot yet authenticate accounts with TOTP enabled")
      |> redirect(to: "/")

    {:halt, conn}
  end

  defp halt_totp(_, conn) do
    {:ok, conn}
  end

  def before_process(Pow.Phoenix.RegistrationController, _method, conn, _config) do
    conn =
      conn
      |> put_flash(:error, "Registrations are disabled")
      |> redirect(to: "/")

    {:halt, conn}
  end
end
