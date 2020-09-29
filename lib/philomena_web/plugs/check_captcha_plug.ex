defmodule PhilomenaWeb.CheckCaptchaPlug do
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
    case valid_solution?(conn.params) do
      true ->
        conn

      false ->
        conn
        |> put_flash(
          :error,
          "There was an error verifying you're not a robot. Please try again."
        )
        |> do_failure_response(conn.assigns.ajax?)
        |> halt()
    end
  end

  defp maybe_check_captcha(conn, _user), do: conn

  defp valid_solution?(%{"h-captcha-response" => captcha_token}) do
    {:ok, %{body: body, status: 200}} =
      Philomena.Http.post(
        "https://hcaptcha.com/siteverify",
        URI.encode_query(%{"response" => captcha_token, "secret" => hcaptcha_secret_key()}),
        [{"Content-Type", "application/x-www-form-urlencoded"}]
      )

    body
    |> Jason.decode!()
    |> Map.get("success", false)
  end

  defp valid_solution?(_params), do: false

  defp do_failure_response(conn, true) do
    conn
    |> put_status(:multiple_choices)
    |> text("")
  end

  defp do_failure_response(conn, _false) do
    redirect(conn, external: conn.assigns.referrer)
  end

  def captcha_enabled? do
    Application.get_env(:philomena, :captcha) != false
  end

  def hcaptcha_secret_key do
    Application.get_env(:philomena, :hcaptcha_secret_key)
  end
end
