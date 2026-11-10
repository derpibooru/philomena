defmodule Philomena.Galleries.QueryBuilder do
  @moduledoc false

  alias Philomena.Galleries.QueryForm

  @doc """
  Builds a gallery search query based on the given parameters.

  ## Parameters

    * `params` - Map of optional search parameters:
      * `title` - Filter by title
      * `creator` - Filter by creator name
      * `included_image` - Filter by galleries containing the image ID
      * `description` - Filter by description
      * `sf` - Sort field:
        * `created_at` - The gallery's creation date
        * `updated_at` - The gallery's last update date
        * `image_count` - The number of images in the gallery
        * `subscriber_count` - The number of subscribers
        * `_score` - Relevance
      * `sd` - Sort direction:
        * `asc` - Results ascending by `sf`
        * `desc` - Results descending by `sf`

  Returns `{:ok, query, query_form}` with an OpenSearch query body for `Galleries`
  that can be used with `PhilomenaQuery.Search`, or `{:error, changeset}` if the
  provided parameters are invalid.
  """
  @spec build_query(map()) :: {:ok, map(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        []
        |> maybe_query_title(query_form)
        |> maybe_query_creator(query_form)
        |> maybe_query_include_image(query_form)
        |> maybe_query_description(query_form)
        |> combine_clauses()
        |> apply_sort(query_form)

      {:ok, query, query_form}
    end
  end

  defp maybe_query_title(query, %QueryForm{title: title}) do
    if title do
      [%{wildcard: %{title: "*#{String.downcase(title)}*"}} | query]
    else
      query
    end
  end

  defp maybe_query_creator(query, %QueryForm{creator: creator}) do
    if creator do
      [%{term: %{creator: String.downcase(creator)}} | query]
    else
      query
    end
  end

  defp maybe_query_include_image(query, %QueryForm{include_image: image_id}) do
    if image_id do
      [%{term: %{image_ids: image_id}} | query]
    else
      query
    end
  end

  defp maybe_query_description(query, %QueryForm{description: description}) do
    if description do
      [%{match_phrase: %{description: description}} | query]
    else
      query
    end
  end

  defp combine_clauses([]), do: %{match_all: %{}}
  defp combine_clauses(clauses), do: %{bool: %{must: clauses}}

  defp apply_sort(query, %QueryForm{sf: sf, sd: sd}) do
    %{
      query: query,
      sort:
        if sf == "created_at" do
          [%{created_at: sd}, %{id: sd}]
        else
          [%{sf => sd}, %{created_at: sd}, %{id: sd}]
        end
    }
  end
end
