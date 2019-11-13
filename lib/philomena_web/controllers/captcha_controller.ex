defmodule PhilomenaWeb.CaptchaController do
  use PhilomenaWeb, :controller

  alias Philomena.Captcha

  def create(conn, _params) do
    captcha = Captcha.create()

    render(conn, "create.html", captcha: captcha, layout: false)
  end
end