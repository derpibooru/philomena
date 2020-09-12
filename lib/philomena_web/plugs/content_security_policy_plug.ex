defmodule PhilomenaWeb.ContentSecurityPolicyPlug do
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
        {:default_src, ["'self'", cdn_uri]},
        {:script_src, ["'self'", cdn_uri | script_src]},
        {:style_src, ["'self'", cdn_uri | style_src]},
        {:object_src, ["'none'"]},
        {:frame_ancestors, ["'none'"]},
        {:frame_src, frame_src || ["'none'"]},
        {:form_action, ["'self'"]},
        {:manifest_src, ["'self'"]},
        {:img_src, ["'self'", "data:", cdn_uri, camo_uri]},
        {:block_all_mixed_content, []}
      ]

      csp_value =
        csp_config
        |> Enum.map(&cspify_element/1)
        |> Enum.join("; ")

      put_resp_header(conn, "content-security-policy", csp_value)
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
