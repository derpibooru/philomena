defmodule PhilomenaWeb.ContentSecurityPolicyPlug do
  import PhilomenaWeb.Config
  import Plug.Conn

  @allowed_sources [
    :script_src,
    :frame_src,
    :style_src
  ]

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    cdn_uri = cdn_uri()
    camo_uri = camo_uri()

    register_before_send(conn, fn conn ->
      config = get_config(conn)

      script_src = Keyword.get(config, :script_src, [])
      style_src = Keyword.get(config, :style_src, [])
      frame_src = Keyword.get(config, :frame_src, nil)

      csp_config = [
        {:default_src, ["'self'"]},
        {:script_src, [default_script_src() | script_src]},
        {:connect_src, [default_connect_src()]},
        {:style_src, [default_style_src() | style_src]},
        {:object_src, ["'none'"]},
        {:frame_ancestors, ["'none'"]},
        {:frame_src, frame_src || ["'none'"]},
        {:form_action, ["'self'"]},
        {:manifest_src, ["'self'"]},
        {:img_src, ["'self'", "blob:", "data:", cdn_uri, camo_uri]},
        {:media_src, ["'self'", "blob:", "data:", cdn_uri, camo_uri]}
      ]

      csp_value =
        csp_config
        |> Enum.map(&cspify_element/1)
        |> Enum.join("; ")

      csp_relaxed? do
        if conn.status == 500 do
          # Allow Plug.Debugger to function in this case
          delete_resp_header(conn, "content-security-policy")
        else
          # Enforce CSP otherwise
          put_resp_header(conn, "content-security-policy", csp_value)
        end
      else
        put_resp_header(conn, "content-security-policy", csp_value)
      end
    end)
  end

  def permit_source(conn, key, value) when key in @allowed_sources do
    conn
    |> get_config()
    |> Keyword.update(key, value, &(value ++ &1))
    |> set_config(conn)
  end

  defp get_config(conn), do: conn.private[:csp] || []
  defp set_config(value, conn), do: put_private(conn, :csp, value)

  defp cdn_uri, do: Application.get_env(:philomena, :cdn_host) |> to_uri()
  defp camo_uri, do: Application.get_env(:philomena, :camo_host) |> to_uri()

  defp default_script_src, do: vite_hmr?(do: "'self' localhost:5173", else: "'self'")

  defp default_connect_src,
    do: vite_hmr?(do: "'self' localhost:5173 ws://localhost:5173", else: "'self'")

  defp default_style_src, do: vite_hmr?(do: "'self' 'unsafe-inline'", else: "'self'")

  defp to_uri(host) when host in [nil, ""], do: ""
  defp to_uri(host), do: URI.to_string(%URI{scheme: "https", host: host})

  defp cspify_element({key, value}) do
    key =
      key
      |> Atom.to_string()
      |> String.replace("_", "-")

    Enum.join([key | value], " ")
  end
end
