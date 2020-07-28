defmodule PhilomenaWeb.CaptchaPlug do
  alias Philomena.Captcha
  import Plug.Conn
  import Phoenix.Controller

  def init([]), do: false

  def call(conn, _opts) do
    case captcha_enabled?() do
      true -> maybe_check_captcha(conn, conn.assigns.current_user)
      false -> conn
    end
  end

  defp maybe_check_captcha(conn, nil) do
    case Captcha.valid_solution?(conn.params) do
      true ->
        conn

      false ->
        conn
        |> put_flash(
          :error,
          "There was an error verifying you're not a robot. Please try again."
        )
        |> do_failure_response(ajax?(conn))
        |> halt()
    end
  end

  defp maybe_check_captcha(conn, _user), do: conn

  defp do_failure_response(conn, true) do
    conn
    |> put_status(:multiple_choices)
    |> text("")
  end

  defp do_failure_response(conn, _false) do
    redirect(conn, external: conn.assigns.referrer)
  end

  def ajax?(conn) do
    case get_req_header(conn, "x-requested-with") do
      [value] -> String.downcase(value) == "xmlhttprequest"
      _ -> false
    end
  end

  def captcha_enabled? do
    Application.get_env(:philomena, :captcha) != false
  end
end
