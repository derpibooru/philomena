defmodule PhilomenaWeb.Tag.AutocompleteController do
  use PhilomenaWeb, :controller

  alias Philomena.Elasticsearch
  alias Philomena.Tags.Tag
  import Ecto.Query

  def show(conn, params) do
    tags =
      case query(params) do
        nil ->
          []

        term ->
          Elasticsearch.search_records(
            Tag,
            %{
              query: %{
                bool: %{
                  should: [
                    %{prefix: %{name: term}},
                    %{prefix: %{name_in_namespace: term}}
                  ]
                }
              },
              sort: %{images: :desc}
            },
            %{page_size: 5},
            Tag |> preload(:aliased_tag)
          )
          |> Enum.map(&(&1.aliased_tag || &1))
          |> Enum.sort_by(&(-&1.images_count))
          |> Enum.map(&%{label: "#{&1.name} (#{&1.images_count})", value: &1.name})
      end

    conn
    |> json(tags)
  end

  defp query(%{"term" => term}) when is_binary(term) and byte_size(term) > 2 do
    term
    |> String.downcase()
    |> String.trim()
  end

  defp query(_params), do: nil
end
