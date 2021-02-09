defmodule PhilomenaWeb.Autocomplete.TagController do
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
          Tag
          |> Elasticsearch.search_definition(
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
            %{page_size: 10}
          )
          |> Elasticsearch.search_records(preload(Tag, :aliased_tag))
          |> Enum.map(&(&1.aliased_tag || &1))
          |> Enum.uniq_by(& &1.id)
          |> Enum.filter(&(&1.images_count > 3))
          |> Enum.sort_by(&(-&1.images_count))
          |> Enum.take(5)
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
