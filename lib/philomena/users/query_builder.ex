defmodule Philomena.Users.QueryBuilder do
  @moduledoc false

  alias Philomena.Users.QueryForm

  @doc """
  Builds a user search query based on the given parameters.

  ## Parameters

    * `params` - Map of optional search parameters:
      * `query` - Search query
      * `sf` - Sort field:
        * `name` - Account name
        * `confirmed_at` - Account confirmation time
        * `updated_at` - Last update time
        * `deleted_at` - Deactivation time
        * `images_count` - Count of images posted
        * `comments_count` - Count of comments on images
        * `image_faves_count` - Count of faves on images
        * `image_votes_count` - Count of votes on images
        * `metadata_updates_count` - Count of tag and source changes
        * `posts_count` - Count of forum posts posted
        * `topics_count` - Count of forum topics posted
        * `_score` - Relevance
      * `sd` - Sort direction:
        * `asc` - Results ascending by `sf`
        * `desc` - Results descending by `sf`

  Returns `{:ok, query, query_form}` with an OpenSearch query body for `Users` that
  can be used with `PhilomenaQuery.Search`, or `{:error, changeset}` if the provided
  parameters are invalid.
  """
  @spec build_query(map()) :: {:ok, map(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      {:ok, apply_sort(query_form.compiled_query, query_form), query_form}
    end
  end

  defp apply_sort(query, %QueryForm{sf: sf, sd: sd}) do
    %{
      query: query,
      sort:
        if sf == "id" do
          [%{id: sd}]
        else
          [%{sf => sd}, %{id: sd}]
        end
    }
  end
end
