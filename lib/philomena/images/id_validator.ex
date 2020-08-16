defmodule Philomena.Images.IDValidator do
  @id_set [%{:id_range => 1..4000000,
             :site => "Derpibooru",
             :url_bases => ["//derpibooru.org/~B",
                            "//derpibooru.org/images/~B",
                            "//trixiebooru.org/~B",
                            "//trixiebooru.org/images/~B"]}]

  @spec validate_id(integer(), String.t()) :: {atom(), String.t()}
  def validate_id(id, url) do
    case get_site(id) do
      {site, url_bases} ->
        case compare_urls(id, url_bases, url) do
          :ok -> {:ok, site}
          _ -> {:nok, site}
        end
      _ ->
        {:nok, nil}
    end
  end

  @spec compare_urls(integer(), [String.t()], String.t()) :: atom()
  defp compare_urls(id, url_bases, test_url) do
    test_url = URI.parse(test_url)
    test_url = URI.to_string(%{test_url | scheme: nil, port: nil})

    case Enum.any?(url_bases, fn(url_base) ->
           url_base |> id_inject(id) == test_url
         end) do
      true ->
        :ok
      _ ->
        :invalid
    end
  end

  @spec id_inject(String.t(), integer()) :: String.t()
  defp id_inject(url_base, id) do
    url_base
      |> :io_lib.format([id])
      |> List.to_string()
  end

  @spec get_site(integer()) :: {String.t(), [String.t()]} | atom()
  defp get_site(id) do
    case Enum.find(@id_set, fn(sitemap) ->
           Enum.member?(sitemap.id_range, id)
         end) do
      %{:site => site, :url_bases => url_bases} ->
        {site, url_bases}
      _ ->
        :no_match
    end
  end
end
