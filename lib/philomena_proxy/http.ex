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
  @type body :: binary()

  @type client_options :: keyword()

  @doc ~S"""
  Perform a HTTP GET request.

  ## Example

      iex> PhilomenaProxy.Http.get("http://example.com", [{"authorization", "Bearer #{token}"}])
      {:ok, %Tesla.Env{...}}

      iex> PhilomenaProxy.Http.get("http://nonexistent.example.com")
      {:error, %Mint.TransportError{reason: :nxdomain}}

  """
  @spec get(url(), header_list(), client_options()) :: Tesla.Env.result()
  def get(url, headers \\ [], options \\ []) do
    Tesla.get(client(headers), url, opts: [adapter: adapter_opts(options)])
  end

  @doc ~S"""
  Perform a HTTP HEAD request.

  ## Example

      iex> PhilomenaProxy.Http.head("http://example.com", [{"authorization", "Bearer #{token}"}])
      {:ok, %Tesla.Env{...}}

      iex> PhilomenaProxy.Http.head("http://nonexistent.example.com")
      {:error, %Mint.TransportError{reason: :nxdomain}}

  """
  @spec head(url(), header_list(), client_options()) :: Tesla.Env.result()
  def head(url, headers \\ [], options \\ []) do
    Tesla.head(client(headers), url, opts: [adapter: adapter_opts(options)])
  end

  @doc ~S"""
  Perform a HTTP POST request.

  ## Example

      iex> PhilomenaProxy.Http.post("http://example.com", "", [{"authorization", "Bearer #{token}"}])
      {:ok, %Tesla.Env{...}}

      iex> PhilomenaProxy.Http.post("http://nonexistent.example.com", "")
      {:error, %Mint.TransportError{reason: :nxdomain}}

  """
  @spec post(url(), body(), header_list(), client_options()) :: Tesla.Env.result()
  def post(url, body, headers \\ [], options \\ []) do
    Tesla.post(client(headers), url, body, opts: [adapter: adapter_opts(options)])
  end

  defp adapter_opts(opts) do
    opts = Keyword.merge(opts, max_body: 125_000_000, inet6: true)

    case Application.get_env(:philomena, :proxy_host) do
      nil ->
        opts

      url ->
        Keyword.merge(opts, proxy: proxy_opts(URI.parse(url)))
    end
  end

  defp proxy_opts(%{host: host, port: port, scheme: "https"}),
    do: {:https, host, port, [transport_opts: [inet6: true]]}

  defp proxy_opts(%{host: host, port: port, scheme: "http"}),
    do: {:http, host, port, [transport_opts: [inet6: true]]}

  defp client(headers) do
    Tesla.client(
      [
        {Tesla.Middleware.FollowRedirects, max_redirects: 1},
        {Tesla.Middleware.Headers,
         [
           {"User-Agent",
            "Mozilla/5.0 (X11; Philomena; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0"}
           | headers
         ]}
      ],
      Tesla.Adapter.Mint
    )
  end
end
