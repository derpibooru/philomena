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
      true ->
        conn

      false ->
        conn
        |> Controller.put_flash(
          :error,
          "There was an error verifying you're not a robot. Please try again."
        )
        |> do_failure_response()
        |> Conn.halt()
    end
  end

  defp maybe_check_captcha(conn, _user), do: conn

  defp do_failure_response(conn) do
    case ajax?(conn) do
      true ->
        conn
        |> Conn.put_status(:multiple_choices)
        |> Controller.text("")
      false ->
        conn
        |> Controller.redirect(external: conn.assigns.referrer)
    end
  end

  def ajax?(conn) do
    case Conn.get_req_header(conn, "x-requested-with") do
      [value] -> String.downcase(value) == "xmlhttprequest"
      _ -> false
    end
  end
end
