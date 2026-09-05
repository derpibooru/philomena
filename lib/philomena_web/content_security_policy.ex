defmodule PhilomenaWeb.ContentSecurityPolicy do
  @moduledoc """
  Builds and serializes the application's Content Security Policy (CSP).

  Policies are represented as maps whose keys are directive names (for example,
  `:script_src`) and whose values are lists of CSP source expressions. The
  policy produced by `conn_policy/2` starts with the application's restrictive
  baseline and then incorporates request-specific and environment-specific
  sources:

    * same-origin sources are allowed for document, script, connection, form,
      manifest, image, and media requests;
    * objects and frame ancestors are denied, while `frame-src` is denied until
      a source is explicitly added;
    * `:cdn_host` and `:camo_host` configuration values are added as HTTPS image
      and media origins; and
    * Vite development origins are added when Vite hot-module reloading is
      enabled.

  Use `merge_policy/2` to append source expressions to an existing policy, and
  `serialize/1` to turn the policy into the value of a
  `content-security-policy` response header.
  """

  alias PhilomenaWeb.Config
  alias PhilomenaWeb.FrontendAssets

  @directives [
    default_src: "default-src",
    base_uri: "base-uri",
    script_src: "script-src",
    connect_src: "connect-src",
    style_src: "style-src",
    object_src: "object-src",
    frame_ancestors: "frame-ancestors",
    frame_src: "frame-src",
    form_action: "form-action",
    manifest_src: "manifest-src",
    img_src: "img-src",
    media_src: "media-src"
  ]

  # An entry of 'none' is not permitted to be extended by any request.
  # Other entries can be extended.
  @base_policy %{
    default_src: ["'self'"],
    base_uri: ["'none'"],
    script_src: ["'self'"],
    connect_src: ["'self'"],
    style_src: ["'self'"],
    object_src: ["'none'"],
    frame_ancestors: ["'none'"],
    frame_src: [],
    form_action: ["'self'"],
    manifest_src: ["'self'"],
    img_src: ["'self'", "blob:", "data:"],
    media_src: ["'self'", "blob:", "data:"]
  }

  @type policy :: %{optional(atom()) => [String.t()]}

  @doc """
  Builds the CSP policy applicable to a `m:Plug.Conn`.

  The returned policy begins with the module's baseline policy, adds the
  configured CDN and Camo hosts to `img-src` and `media-src`, and adds the Vite
  development and websocket origins when Vite hot-module reloading is enabled.

  `additions` contains request-specific directive sources and is merged last,
  so callers can extend the baseline for a particular response. It defaults to
  an empty policy.

  Hosts configured through `:cdn_host` and `:camo_host` are interpreted as host
  names and serialized as HTTPS origins. `conn` is used to derive the Vite
  origins, so it should contain the request host when hot reloading is in use.

  ## Examples

      iex> conn = Plug.Test.conn(:get, "/")
      iex> policy = PhilomenaWeb.ContentSecurityPolicy.conn_policy(conn)
      iex> policy.default_src
      ["'self'"]

  """
  @spec conn_policy(Plug.Conn.t(), policy()) :: policy()
  def conn_policy(conn, additions \\ %{}) do
    @base_policy
    |> maybe_media_origin(Application.get_env(:philomena, :cdn_host))
    |> maybe_media_origin(Application.get_env(:philomena, :camo_host))
    |> maybe_vite_hmr(conn, Config.vite_hmr?())
    |> merge_policy(additions)
  end

  @doc """
  Appends source expressions from `additions` to a CSP `policy`.

  Entries with the same directive are concatenated in their existing order;
  directives present only in `additions` are added to the map. This function
  can be used repeatedly while a request accumulates permissions.

  Unknown directive keys are preserved in the returned map, although
  `serialize/1` emits only the directives supported by this module.

  ## Examples

      iex> policy = %{script_src: ["'self'"]}
      iex> PhilomenaWeb.ContentSecurityPolicy.merge_policy(policy, %{script_src: ["https://cdn.example"]})
      %{script_src: ["'self'", "https://cdn.example"]}

  """
  @spec merge_policy(policy(), policy()) :: policy()
  def merge_policy(policy, additions) do
    Map.merge(policy, additions, fn _key, old_sources, new_sources ->
      old_sources ++ new_sources
    end)
  end

  @doc """
  Serializes a policy map as a `Content-Security-Policy` header value.

  Directives are emitted in a stable order. Source expressions for each
  directive are de-duplicated while preserving their first-seen order; a
  directive with no sources is emitted as `<directive> 'none'`. Only the
  directives supported by this module are emitted, even when `policy` contains
  additional keys.

  ## Examples

      iex> policy = %{default_src: ["'self'"], frame_src: ["https://frame.example"]}
      iex> serialized = PhilomenaWeb.ContentSecurityPolicy.serialize(policy)
      iex> String.split(serialized, "; ") |> Enum.take(2)
      ["default-src 'self'", "script-src 'none'"]

  """
  @spec serialize(policy()) :: String.t()
  def serialize(policy) do
    @directives
    |> Enum.map(fn {directive, name} ->
      policy
      |> effective_values(directive)
      |> then(&Enum.join([name | &1], " "))
    end)
    |> Enum.join("; ")
  end

  defp effective_values(policy, directive) do
    policy
    |> Map.get(directive, [])
    |> Enum.uniq()
    |> case do
      [] ->
        ["'none'"]

      values ->
        values
    end
  end

  defp maybe_vite_hmr(policy, _conn, false),
    do: policy

  defp maybe_vite_hmr(policy, conn, true) do
    origin = FrontendAssets.vite_origin(conn)
    websocket_origin = FrontendAssets.vite_websocket_origin(conn)

    merge_policy(policy, %{
      script_src: [origin],
      connect_src: [origin, websocket_origin],
      style_sources: ["'unsafe-inline'"]
    })
  end

  defp maybe_media_origin(policy, origin) when origin in [nil, ""],
    do: policy

  defp maybe_media_origin(policy, origin) do
    origin = URI.to_string(%URI{scheme: "https", host: origin})

    merge_policy(policy, %{
      img_src: [origin],
      media_src: [origin]
    })
  end
end
