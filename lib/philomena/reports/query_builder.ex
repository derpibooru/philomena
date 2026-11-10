defmodule Philomena.Reports.QueryBuilder do
  @moduledoc false

  alias Philomena.Reports.QueryForm
  alias Philomena.Users.User

  @doc """
  Builds a report search query based on the given parameters.

  ## Parameters

    * `params` - Map of optional search parameters:
      * `query` - Search query

  Returns `{:ok, query, query_form}` with an OpenSearch query body for `Reports`
  that can be used with `PhilomenaQuery.Search`, or `{:error, changeset}` if the
  provided parameters are invalid.
  """
  @spec build_query(map(), User.t()) :: {:ok, map(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}, %User{} = user) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(user.id, params)
           |> Ecto.Changeset.apply_action(:create) do
      {:ok, apply_sort(query_form.compiled_query), query_form}
    end
  end

  defp apply_sort(query) do
    %{
      query: query,
      sort: [
        %{open: :desc},
        %{state: :desc},
        %{created_at: :desc}
      ]
    }
  end
end
