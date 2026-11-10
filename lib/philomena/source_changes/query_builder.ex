defmodule Philomena.SourceChanges.QueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.SourceChanges.QueryForm

  @doc """
  Builds a source change query for the given parameters.

  ## Parameters

    * `added` - Optional filter by state. When omitted, filters nothing.

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec build_query(map()) ::
          {:ok, Ecto.Query.t(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        SourceChange
        |> maybe_filter_added(query_form)
        |> order_by(desc: :created_at, desc: :id)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_added(query, %QueryForm{added: added}) do
    case added do
      true ->
        where(query, added: true)

      false ->
        where(query, added: false)

      nil ->
        query
    end
  end
end
