defmodule PhilomenaWeb.CaptchaPlug do
  alias PhilomenaWeb.ContentSecurityPolicyPlug

  @hcaptcha_url ["https://hcaptcha.com", "https://*.hcaptcha.com"]

  def init(_opts) do
    []
  end

  # Set CSP headers for serving captchas.
  # Only holepunch CSP if the user is not signed in.
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    user = conn.assigns.current_user

    maybe_assign_csp_headers(conn, user)
  end

  defp maybe_assign_csp_headers(conn, nil) do
    conn
    |> ContentSecurityPolicyPlug.permit_source(:script_src, @hcaptcha_url)
    |> ContentSecurityPolicyPlug.permit_source(:frame_src, @hcaptcha_url)
    |> ContentSecurityPolicyPlug.permit_source(:style_src, @hcaptcha_url)
  end

  defp maybe_assign_csp_headers(conn, _user) do
    conn
  end
end
