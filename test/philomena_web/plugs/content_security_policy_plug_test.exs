defmodule PhilomenaWeb.ContentSecurityPolicyPlugTest do
  use ExUnit.Case, async: false

  alias PhilomenaWeb.ContentSecurityPolicy
  alias PhilomenaWeb.ContentSecurityPolicyPlug
  alias PhilomenaWeb.FrontendAssets

  @config_keys [:cdn_host, :camo_host, :vite_reload, :csp_relax_on_error]

  setup do
    values = Map.new(@config_keys, &{&1, Application.get_env(:philomena, &1)})

    on_exit(fn ->
      Enum.each(values, fn
        {key, nil} -> Application.delete_env(:philomena, key)
        {key, value} -> Application.put_env(:philomena, key, value)
      end)
    end)

    Enum.each(@config_keys, &Application.delete_env(:philomena, &1))
    :ok
  end

  test "builds a deterministic policy and omits unset origins" do
    conn = Plug.Test.conn(:get, "/") |> Map.put(:host, "localhost")

    policy =
      conn
      |> ContentSecurityPolicy.conn_policy()
      |> ContentSecurityPolicy.serialize()

    assert policy =~ "default-src 'self'"
    assert policy =~ "frame-src 'none'"
    assert policy =~ "img-src 'self' blob: data:"
    refute policy =~ "  "
    refute policy =~ "https://"
  end

  test "merges and deduplicates request-specific sources" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Map.put(:host, "localhost")
      |> ContentSecurityPolicyPlug.call([])
      |> ContentSecurityPolicyPlug.permit_sources(%{
        frame_src: ["https://hcaptcha.com", "https://hcaptcha.com"]
      })
      |> Plug.Conn.send_resp(200, "ok")

    [policy] = Plug.Conn.get_resp_header(conn, "content-security-policy")
    assert policy =~ "frame-src https://hcaptcha.com"
    refute policy =~ "frame-src https://hcaptcha.com https://hcaptcha.com"
  end

  test "uses the shared Vite origin in both policy and asset URLs" do
    Application.put_env(:philomena, :vite_reload, true)
    conn = Plug.Test.conn(:get, "/") |> Map.put(:host, "192.168.1.10")

    origin = FrontendAssets.vite_origin(conn)

    policy =
      conn
      |> ContentSecurityPolicy.conn_policy()
      |> ContentSecurityPolicy.serialize()

    assert FrontendAssets.vite_asset_url(conn, "/js/app.ts") == origin <> "/js/app.ts"
    assert policy =~ "script-src 'self' #{origin}"
    assert policy =~ "connect-src 'self' #{origin} ws://192.168.1.10:5173"
  end

  test "adds media-specific hosts to media-src and img-src when provided" do
    # With neither
    conn = Plug.Test.conn(:get, "/") |> Map.put(:host, "localhost")

    policy =
      conn
      |> ContentSecurityPolicy.conn_policy()
      |> ContentSecurityPolicy.serialize()

    assert policy =~ "img-src 'self' blob: data:"
    assert policy =~ "media-src 'self' blob: data:"

    # With one
    Application.put_env(:philomena, :camo_host, "philomena-camo-host.example")

    conn = Plug.Test.conn(:get, "/") |> Map.put(:host, "localhost")

    policy =
      conn
      |> ContentSecurityPolicy.conn_policy()
      |> ContentSecurityPolicy.serialize()

    assert policy =~ "img-src 'self' blob: data: https://philomena-camo-host.example"
    assert policy =~ "media-src 'self' blob: data: https://philomena-camo-host.example"

    # With both
    Application.put_env(:philomena, :cdn_host, "philomena-cdn-host.example")

    conn = Plug.Test.conn(:get, "/") |> Map.put(:host, "localhost")

    policy =
      conn
      |> ContentSecurityPolicy.conn_policy()
      |> ContentSecurityPolicy.serialize()

    assert policy =~
             "img-src 'self' blob: data: https://philomena-cdn-host.example https://philomena-camo-host.example"

    assert policy =~
             "media-src 'self' blob: data: https://philomena-cdn-host.example https://philomena-camo-host.example"
  end

  test "only relaxes CSP on errors when explicitly enabled" do
    conn = Plug.Test.conn(:get, "/") |> Map.put(:host, "localhost")

    strict_conn = conn |> ContentSecurityPolicyPlug.call([]) |> Plug.Conn.send_resp(500, "error")
    refute Plug.Conn.get_resp_header(strict_conn, "content-security-policy") == []

    Application.put_env(:philomena, :csp_relax_on_error, true)
    relaxed_conn = conn |> ContentSecurityPolicyPlug.call([]) |> Plug.Conn.send_resp(500, "error")
    assert Plug.Conn.get_resp_header(relaxed_conn, "content-security-policy") == []
  end
end
