defmodule PhilomenaWeb.CaptchaPlug do
  alias Philomena.Captcha
  alias Phoenix.Controller
  alias Plug.Conn

  def init([]), do: false

  def call(conn, _opts) do
    user = conn |> Pow.Plug.current_user()

    conn
    |> maybe_check_captcha(user)
  end

  defp maybe_check_captcha(conn, nil) do
    case Captcha.valid_solution?(conn.params) do
      true  -> conn
      false ->
        conn
        |> Controller.put_flash(:error, "There was an error verifying you're not a robot. Please try again.")
        |> Controller.redirect(external: conn.assigns.referrer)
        |> Conn.halt()
    end
  end
  defp maybe_check_captcha(conn, _user), do: conn
end
