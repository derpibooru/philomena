defmodule Philomena.Http do
  @user_agent ["User-Agent": "Mozilla/5.0 (X11; Philomena; Linux x86_64; rv:70.0) Gecko/20100101 Firefox/70.0"]

  def get!(url, headers \\ [], options \\ []) do
    headers = Keyword.merge(@user_agent, headers)
    options = Keyword.merge(options, proxy: proxy_host())

    HTTPoison.get!(url, headers, options)
  end

  def head!(url, headers \\ [], options \\ []) do
    headers = Keyword.merge(@user_agent, headers)
    options = Keyword.merge(options, proxy: proxy_host())

    HTTPoison.head!(url, headers, options)
  end

  defp proxy_host do
    Application.get_env(:philomena, :proxy_host)
  end
end