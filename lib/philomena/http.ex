defmodule Philomena.Http do
  def get!(url, headers \\ [], options \\ []) do
    Tesla.get!(client(headers), url, opts: [adapter: adapter_opts(options)])
  end

  def head!(url, headers \\ [], options \\ []) do
    Tesla.head!(client(headers), url, opts: [adapter: adapter_opts(options)])
  end

  defp adapter_opts(opts) do
    opts = Keyword.merge(opts, max_body: 100_000_000)

    case Application.get_env(:philomena, :proxy_host) do
      nil ->
        opts
      "" ->
        opts

      url ->
        IO.puts("Setting proxy host to #{url}")
        Keyword.merge(opts, proxy: proxy_opts(URI.parse(url)))
    end
  end

  defp proxy_opts(%{host: host, port: port, scheme: "https"}), do: {:https, host, port, []}
  defp proxy_opts(%{host: host, port: port, scheme: "http"}), do: {:http, host, port, []}

  defp client(headers) do
    Tesla.client(
      [
        {Tesla.Middleware.Headers,
         [
           {"User-Agent",
            "Mozilla/5.0 (X11; Philomena; Linux x86_64; rv:70.0) Gecko/20100101 Firefox/76.0"}
           | headers
         ]}
      ],
      Tesla.Adapter.Mint
    )
  end
end
