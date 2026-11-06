defmodule PhilomenaWeb.CheckCaptchaPlugTest do
  # Enables the captcha through global application config.
  use PhilomenaWeb.ConnCase, async: false

  alias PhilomenaWeb.CheckCaptchaPlug

  setup do
    Application.put_env(:philomena, :captcha, true)
    on_exit(fn -> Application.put_env(:philomena, :captcha, false) end)
  end

  defp check_captcha(conn) do
    conn
    |> Map.put(:params, %{"h-captcha-response" => "token"})
    |> init_test_session(%{})
    |> fetch_flash()
    |> assign(:current_user, nil)
    |> assign(:ajax?, true)
    |> CheckCaptchaPlug.call([])
  end

  test "an anonymous request with a verified solution passes", %{conn: conn} do
    Req.Test.stub(PhilomenaProxy.Http, &Req.Test.json(&1, %{"success" => true}))

    refute check_captcha(conn).halted
  end

  test "an hCaptcha error response fails the captcha", %{conn: conn} do
    Req.Test.stub(PhilomenaProxy.Http, &Plug.Conn.send_resp(&1, 500, "Internal Server Error"))

    conn = check_captcha(conn)

    assert conn.halted
    assert response(conn, 300) == ""
  end
end
