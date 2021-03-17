defmodule Philomena.Http do
  def get(url, headers \\ [], options \\ []) do
    Tesla.get(client(headers), url, opts: [adapter: adapter_opts(options)])
  end

  def head(url, headers \\ [], options \\ []) do
    Tesla.head(client(headers), url, opts: [adapter: adapter_opts(options)])
  end

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
