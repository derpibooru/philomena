defmodule Philomena.Reports do
  @moduledoc """
  The Reports context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Elasticsearch
  alias Philomena.Reports.Report
  alias Philomena.Reports.ElasticsearchIndex, as: ReportIndex
  alias Philomena.IndexWorker
  alias Philomena.Polymorphic

  @doc """
  Returns the list of reports.

  ## Examples

      iex> list_reports()
      [%Report{}, ...]

  """
  def list_reports do
    Repo.all(Report)
  end

  @doc """
  Gets a single report.

  Raises `Ecto.NoResultsError` if the Report does not exist.

  ## Examples

      iex> get_report!(123)
      %Report{}

      iex> get_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_report!(id), do: Repo.get!(Report, id)

  @doc """
  Creates a report.

  ## Examples

      iex> create_report(%{field: value})
      {:ok, %Report{}}

      iex> create_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_report(reportable_id, reportable_type, attribution, attrs \\ %{}) do
    %Report{reportable_id: reportable_id, reportable_type: reportable_type}
    |> Report.creation_changeset(attrs, attribution)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Updates a report.

  ## Examples

      iex> update_report(report, %{field: new_value})
      {:ok, %Report{}}

      iex> update_report(report, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_report(%Report{} = report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Deletes a Report.

  ## Examples

      iex> delete_report(report)
      {:ok, %Report{}}

      iex> delete_report(report)
      {:error, %Ecto.Changeset{}}

  """
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking report changes.

  ## Examples

      iex> change_report(report)
      %Ecto.Changeset{source: %Report{}}

  """
  def change_report(%Report{} = report) do
    Report.changeset(report, %{})
  end

  def claim_report(%Report{} = report, user) do
    report
    |> Report.claim_changeset(user)
    |> Repo.update()
    |> reindex_after_update()
  end

  def unclaim_report(%Report{} = report) do
    report
    |> Report.unclaim_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  def close_report(%Report{} = report, user) do
    report
    |> Report.close_changeset(user)
    |> Repo.update()
    |> reindex_after_update()
  end

  def user_name_reindex(old_name, new_name) do
    data = ReportIndex.user_name_update_by_query(old_name, new_name)

    Elasticsearch.update_by_query(Report, data.query, data.set_replacements, data.replacements)
  end

  defp reindex_after_update({:ok, report}) do
    reindex_report(report)

    {:ok, report}
  end

  defp reindex_after_update(result) do
    result
  end

  def reindex_reports(report_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", report_ids])

    report_ids
  end

  def reindex_report(%Report{} = report) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", [report.id]])

    report
  end

  def perform_reindex(column, condition) do
    Report
    |> where([r], field(r, ^column) in ^condition)
    |> preload([:user, :admin])
    |> Repo.all()
    |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])
    |> Enum.map(&Elasticsearch.index_document(&1, Report))
  end

  def count_reports(user) do
    if Canada.Can.can?(user, :index, Report) do
      Report
      |> where(open: true)
      |> Repo.aggregate(:count, :id)
    else
      nil
    end
  end
end
