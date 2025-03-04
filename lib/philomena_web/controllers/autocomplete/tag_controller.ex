defmodule PhilomenaWeb.Autocomplete.TagController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Search
  alias Philomena.Tags.Tag
  import Ecto.Query

  def show(conn, %{"vsn" => "2"} = params), do: show_v2(conn, params)
  def show(conn, params), do: show_v1(conn, params)

  # Returns a list of tag suggestions for an incomplete term. Does a prefix search
  # on the canonical tag names and their aliases.
  #
  # See the docs on `show_v1` for the explanation on the breaking change we made
  # in the `v2` version.
  defp show_v2(conn, params) do
    with {:ok, term} <- extract_term_v2(params),
         {:ok, limit} <- extract_limit(params) do
      suggestions = search(term, limit)
      json(conn, %{suggestions: suggestions})
    else
      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  defp extract_term_v2(%{"term" => term}) when is_binary(term) and byte_size(term) > 2 do
    result =
      term
      |> String.downcase()
      |> String.trim()

    {:ok, result}
  end

  defp extract_term_v2(%{"term" => _}),
    do: {:error, "Term is too short, must be at least 3 characters"}

  defp extract_term_v2(_params), do: {:error, "Term is missing"}

  defp extract_limit(params) do
    limit =
      params
      |> Map.get("limit", "10")
      |> Integer.parse()

    case limit do
      {limit, ""} when limit > 0 and limit <= 10 ->
        {:ok, limit}

      _ ->
        {:error, "Limit must be an integer between 1 and 10"}
    end
  end

  @spec search(String.t(), integer()) :: [map()]
  defp search(term, limit) do
    Tag
    |> Search.search_definition(
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
    |> Search.search_records(preload(Tag, :aliased_tag))
    |> Enum.map(
      &%{
        :alias => if(is_nil(&1.aliased_tag), do: nil, else: &1.name),
        canonical: if(is_nil(&1.aliased_tag), do: &1.name, else: &1.aliased_tag.name),
        images:
          if(is_nil(&1.aliased_tag), do: &1.images_count, else: &1.aliased_tag.images_count),
        id: &1.id
      }
    )
    |> Enum.filter(&(&1.images > 0))
    |> Enum.take(limit)
    |> Enum.map(
      &%{
        :alias => &1.alias,
        canonical: &1.canonical,
        images: &1.images
      }
    )
  end

  # Version 1 is kept for backwards compatibility with the older versions of
  # the frontend application that may still be cached in user's browsers. Don't
  # change this code! All the new development should be done in the `v2` version.
  #
  # The problem of `v1` was that it was doing the work of formatting the completion
  # results on the backend, which was not ideal. So instead, the `v2` version
  # was created to return the raw data in fully structured JSON format, which
  # the frontend application can then format and style as needed.
  defp show_v1(conn, params) do
    tags =
      case extract_term(params) do
        nil ->
          []

        term ->
          Tag
          |> Search.search_definition(
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
          |> Search.search_records(preload(Tag, :aliased_tag))
          |> Enum.map(&(&1.aliased_tag || &1))
          |> Enum.uniq_by(& &1.id)
          |> Enum.filter(&(&1.images_count > 0))
          |> Enum.sort_by(&(-&1.images_count))
          |> Enum.take(5)
          |> Enum.map(&%{label: "#{&1.name} (#{&1.images_count})", value: &1.name})
      end

    conn
    |> json(tags)
  end

  defp extract_term(%{"term" => term}) when is_binary(term) and byte_size(term) > 2 do
    term
    |> String.downcase()
    |> String.trim()
  end

  defp extract_term(_params), do: nil
end
