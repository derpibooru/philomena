defmodule PhilomenaWeb.Tag.AutocompleteController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag

  def show(conn, params) do
    tags =
      case query(params) do
        nil ->
          []

        term ->
          Tag.search_records(
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
            Tag
          )
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