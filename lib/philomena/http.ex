defmodule Philomena.Http do
  def get!(url, headers \\ [], options \\ []) do
    options = Keyword.merge(options, proxy: proxy_host())

    HTTPoison.get!(url, headers, options)
  end

  def head!(url, headers \\ [], options \\ []) do
    options = Keyword.merge(options, proxy: proxy_host())

    HTTPoison.head!(url, headers, options)
  end

  defp proxy_host do
    Application.get_env(:philomena, :proxy_host)
  end
end