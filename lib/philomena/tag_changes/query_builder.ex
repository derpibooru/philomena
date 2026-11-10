defmodule Philomena.TagChanges.QueryBuilder do
  @moduledoc false

  alias Philomena.Users.User
  alias Philomena.TagChanges.QueryForm

  @doc """
  Builds a tag change search query based on the given parameters.

  ## Parameters

    * `params` - Map of optional search parameters:
      * `tcq` - Search query
      * `sf` - Sort field:
        * `created_at` - Creation timestamp
        * `tag_count` - Number of tags added and removed
        * `added_tag_count` - Number of tags added
        * `removed_tag_count` - Number of tags removed
      * `sd` - Sort direction:
        * `asc` - Results ascending by `sf`
        * `desc` - Results descending by `sf`

  Returns `{:ok, query, query_form}` with an OpenSearch query body for `TagChanges
  that can be used with `PhilomenaQuery.Search`, or `{:error, changeset}` if the
  provided parameters are invalid.
  """
  @spec build_query(User.t() | nil, map()) ::
          {:ok, map(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(user, params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(user, params)
           |> Ecto.Changeset.apply_action(:create) do
      body = %{
        query: query_form.compiled_query,
        sort: [
          %{query_form.sf => query_form.sd},
          %{"id" => query_form.sd}
        ]
      }

      {:ok, body, query_form}
    end
  end
end
