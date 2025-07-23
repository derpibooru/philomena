defmodule PhilomenaProxy.Http do
  @moduledoc """
  HTTP client implementation.

  This applies the Philomena User-Agent header, and optionally proxies traffic through a SOCKS5
  HTTP proxy to allow the application to connect when the local network is restricted.

  If a proxy host is not specified in the configuration, then a proxy is not used and external
  traffic is originated from the same network as application.

  Proxy options are read from environment variables at runtime by Philomena.

      config :philomena,
        proxy_host: System.get_env("PROXY_HOST"),

  """

  @type url :: String.t()
  @type header_list :: [{String.t(), String.t()}]
  @type body :: iodata()
  @type result :: {:ok, Req.Response.t()} | {:error, Exception.t()}

  @user_agent "Mozilla/5.0 (X11; Philomena; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0"
  @max_body 131_072_000

  @max_body_key :resp_body_size

  @doc ~S"""
  Perform a HTTP GET request.

  ## Example

      iex> PhilomenaProxy.Http.get("http://example.com", [{"authorization", "Bearer #{token}"}])
      {:ok, %{status: 200, body: ...}}

      iex> PhilomenaProxy.Http.get("http://nonexistent.example.com")
      {:error, %Req.TransportError{reason: :nxdomain}}

  """
  @spec get(url(), header_list()) :: result()
  def get(url, headers \\ []) do
    request(:get, url, [], headers)
  end

  @doc ~S"""
  Perform a HTTP HEAD request.

  ## Example

      iex> PhilomenaProxy.Http.head("http://example.com", [{"authorization", "Bearer #{token}"}])
      {:ok, %{status: 200, body: ...}}

      iex> PhilomenaProxy.Http.head("http://nonexistent.example.com")
      {:error, %Req.TransportError{reason: :nxdomain}}

  """
  @spec head(url(), header_list()) :: result()
  def head(url, headers \\ []) do
    request(:head, url, [], headers)
  end

  @doc ~S"""
  Perform a HTTP POST request.

  ## Example

      iex> PhilomenaProxy.Http.post("http://example.com", "", [{"authorization", "Bearer #{token}"}])
      {:ok, %{status: 200, body: ...}}

      iex> PhilomenaProxy.Http.post("http://nonexistent.example.com", "")
      {:error, %Req.TransportError{reason: :nxdomain}}

  """
  @spec post(url(), body(), header_list()) :: result()
  def post(url, body, headers \\ []) do
    request(:post, url, body, headers)
  end

  @spec request(atom(), String.t(), iodata(), header_list()) :: result()
  defp request(method, url, body, headers) do
    Req.new(
      method: method,
      url: url,
      body: body,
      headers: [{:user_agent, @user_agent} | headers],
      max_redirects: 1,
      connect_options: connect_options(),
      inet6: true,
      into: &stream_response_callback/2,
      decode_body: false
    )
    |> Req.Request.put_private(@max_body_key, 0)
    |> Req.request()
  end

  defp connect_options do
    case Application.get_env(:philomena, :proxy_host) do
      nil ->
        []

      proxy_url ->
        [proxy: proxy_opts(URI.parse(proxy_url))]
    end
  end

  defp proxy_opts(%{host: host, port: port, scheme: "https"}),
    do: {:https, host, port, [transport_opts: [inet6: true]]}

  defp proxy_opts(%{host: host, port: port, scheme: "http"}),
    do: {:http, host, port, [transport_opts: [inet6: true]]}

  defp stream_response_callback({:data, data}, {req, resp}) do
    req = update_in(req.private[@max_body_key], &(&1 + byte_size(data)))
    resp = update_in(resp.body, &<<&1::binary, data::binary>>)

    if req.private.resp_body_size < @max_body do
      {:cont, {req, resp}}
    else
      {:halt, {req, RuntimeError.exception("body too big")}}
    end
  end
end
