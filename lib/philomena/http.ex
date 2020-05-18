defmodule Philomena.Http do
  @user_agent [
    "User-Agent":
      "Mozilla/5.0 (X11; Philomena; Linux x86_64; rv:70.0) Gecko/20100101 Firefox/70.0"
  ]

  def get!(url, headers \\ [], options \\ []) do
    headers = Keyword.merge(@user_agent, headers) |> add_host(url)
    options = Keyword.merge(options, proxy: proxy_host(), ssl: [insecure: true])

    HTTPoison.get!(url, headers, options)
  end

  def head!(url, headers \\ [], options \\ []) do
    headers = Keyword.merge(@user_agent, headers) |> add_host(url)
    options = Keyword.merge(options, proxy: proxy_host(), ssl: [insecure: true])

    HTTPoison.head!(url, headers, options)
  end

  # Add host for caching proxies, since hackney doesn't do it for us
  defp add_host(headers, url) do
    %{host: host} = URI.parse(url)

    Keyword.merge([Host: host, Connection: "close"], headers)
  end

  defp proxy_host do
    Application.get_env(:philomena, :proxy_host)
  end
end
