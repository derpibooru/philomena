defmodule Philomena.Images.IDValidator do
  @moduledoc """
  Validates import IDs against source sites.
  """

  @id_set [%{
    :id_range => 1..4000000,
    :site => "Derpibooru",
    :url_regexes => [
      "^https?://derpicdn.net/img/(view|download)/\\d{4}/\\d{1,2}/\\d{1,2}/~B.*..+"
    ]}]

  @doc """
  Takes import ID and source URL.

  Returns {:ok, site} if valid pair, {:nok, site} if site found for ID but URL
  is invalid, and {:nok, nil} if no site found.

  ## Examples

    iex> validate_id(4096, "https://derpicdn.net/img/view/2012/5/27/4096.jpg")
    {:ok, "Derpibooru"}

    iex> validate_id(8192, "https://derpicdn.net/img/view/2012/5/27/4096.jpg")
    {:nok, "Derpibooru"}

    iex> validate_id(-1, "https://derpicdn.net/img/view/2012/5/27/4096.jpg")
    {:nok, nil}

  """
  @spec validate_id(integer(), String.t()) :: {atom(), String.t()}
  def validate_id(id, url) do
    case get_site(id) do
      {site, url_regexes} ->
        case compare_urls(id, url_regexes, url) do
          :ok -> {:ok, site}
          _ -> {:nok, site}
        end
      _ ->
        {:nok, nil}
    end
  end

  @doc false
  @spec compare_urls(integer(), [String.t()], String.t()) :: atom()
  def compare_urls(id, url_regexes, test_url) do
    case Enum.any?(url_regexes, fn(url_regex) ->
           url_regex
             |> id_inject(id)
             |> Regex.compile!("iU")
             |> Regex.match?(test_url)
         end) do
      true ->
        :ok
      _ ->
        :invalid
    end
  end

  @doc false
  @spec id_inject(String.t(), integer()) :: String.t()
  def id_inject(url_base, id) do
    url_base
      |> :io_lib.format([id])
      |> List.to_string()
  end

  @doc false
  @spec get_site(integer()) :: {String.t(), [String.t()]} | atom()
  def get_site(id) do
    case Enum.find(@id_set, fn(sitemap) ->
           Enum.member?(sitemap.id_range, id)
         end) do
      %{:site => site, :url_regexes => url_regexes} ->
        {site, url_regexes}
      _ ->
        :no_match
    end
  end
end
