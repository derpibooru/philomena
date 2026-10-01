defmodule Philomena.DuplicateReports.QueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports.QueryForm

  @doc """
  Builds the staff duplicate report query for the given parameters.

  ## Parameters

    * `states` - Filter by duplicate report states; the default includes open
      and claimed reports
    * `sd` - Sort direction

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
        DuplicateReport
        |> maybe_filter_states(query_form)
        |> apply_sort(query_form)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_states(query, %QueryForm{states: states}) do
    if states do
      where(query, [report], report.state in ^states)
    else
      query
    end
  end

  defp apply_sort(query, %QueryForm{sd: sd, states: states}) do
    direction =
      case sd do
        "asc" -> :asc
        _desc -> :desc
      end

    # If the query is only for open reports, claim state should
    # be specifically part of the ordering. (When this is migrated to
    # OpenSearch, this condition can be dropped and claimed should
    # always be part of the ordering.)
    sorts =
      if only_matches_open_reports?(states) do
        claimed_predicate = dynamic([report], report.state == "claimed")
        [{direction, claimed_predicate}, {direction, :created_at}, {direction, :id}]
      else
        [{direction, :created_at}, {direction, :id}]
      end

    order_by(query, ^sorts)
  end

  defp only_matches_open_reports?(states) do
    not is_nil(states) and Enum.empty?(states -- DuplicateReport.open_states())
  end
end
