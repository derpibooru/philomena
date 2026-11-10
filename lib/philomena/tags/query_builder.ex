defmodule Philomena.Tags.QueryBuilder do
  @moduledoc false

  alias Philomena.Tags.QueryForm

  @doc """
  Builds a tag search query based on the given parameters.

  ## Parameters

    * `params` - Map of optional search parameters:
      * `query` - Search query

  Returns `{:ok, query, query_form}` with an OpenSearch query body for `Tags` that
  can be used with `PhilomenaQuery.Search`, or `{:error, changeset}` if the provided
  parameters are invalid.
  """
  @spec build_query(map()) ::
          {:ok, map(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      body = %{
        query: query_form.compiled_query,
        sort: [%{images: :desc}, %{name: :asc}, %{id: :asc}]
      }

      {:ok, body, query_form}
    end
  end
end
