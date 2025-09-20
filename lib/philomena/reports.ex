defmodule Philomena.Reports do
  @moduledoc """
  The Reports context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.Reports.Report
  alias Philomena.Reports.SearchIndex, as: ReportIndex
  alias Philomena.IndexWorker
  alias Philomena.Polymorphic

  @doc """
  Returns the current number of open reports.

  If the user is allowed to view reports, returns the current count.
  If the user is not allowed to view reports, returns `nil`.

  ## Examples

      iex> count_reports(%User{})
      nil

      iex> count_reports(%User{role: "admin"})
      4

  """
  def count_open_reports(user) do
    if Canada.Can.can?(user, :index, Report) do
      Report
      |> where(open: true)
      |> Repo.aggregate(:count)
    else
      nil
    end
  end

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
  def create_report({reportable_type, reportable_id} = _type_and_id, attribution, attrs \\ %{}) do
    %Report{reportable_type: reportable_type, reportable_id: reportable_id}
    |> Report.creation_changeset(attrs, attribution)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Returns an `m:Ecto.Query` which updates all open reports for the given `reportable_type`
  and `reportable_id` to close them.

  Because this is only a query due to the limitations of `m:Ecto.Multi`, this must be
  coupled with an associated call to `reindex_reports/1` to operate correctly, e.g.:

      report_query = Reports.close_report_query({"Image", image.id}, user)

      Multi.new()
      |> Multi.update_all(:reports, report_query, [])
      |> Repo.transaction()
      |> case do
        {:ok, %{reports: {_count, reports}} = result} ->
          Reports.reindex_reports(reports)

          {:ok, result}

        error ->
          error
      end

  Use `close_reports/2` to close and reindex reports in one step outside an `m:Ecto.Multi`.

  ## Examples

      iex> close_report_query({"Image", 1}, %User{})
      #Ecto.Query<...>

  """
  def close_report_query({reportable_type, reportable_id} = _type_and_id, closing_user) do
    from r in Report,
      where:
        r.reportable_type == ^reportable_type and r.reportable_id == ^reportable_id and
          r.open == true,
      select: r.id,
      update: [set: [open: false, state: "closed", admin_id: ^closing_user.id]]
  end

  @doc """
  Closes all open reports for the given reportable type and ID, marking them as closed by the specified user.
  Also reindexes the affected reports.

  Returns `{:ok, {count, reports}}`.
  """
  def close_reports(type_and_id, closing_user) do
    {_count, reports} =
      result = Repo.update_all(close_report_query(type_and_id, closing_user), [])

    reindex_reports(reports)
    {:ok, result}
  end

  @doc """
  Automatically create a report with the given category and reason on the given
  `reportable_id` and `reportable_type`.

  ## Examples

      iex> create_system_report({"Comment", 1}, "Other", "Custom report reason")
      {:ok, %Report{}}

  """
  def create_system_report({reportable_type, reportable_id} = _type_and_id, category, reason) do
    attrs = %{
      reason: reason,
      category: category,
      user_agent: "system"
    }

    attribution = %{
      system: true,
      ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
      fingerprint: "ffff"
    }

    %Report{reportable_type: reportable_type, reportable_id: reportable_id}
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

  @doc """
  Marks the report as claimed by the given user.

  ## Example

      iex> claim_report(%Report{}, %User{})
      {:ok, %Report{}}

  """
  def claim_report(%Report{} = report, user) do
    report
    |> Report.claim_changeset(user)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Marks the report as unclaimed.

  ## Example

      iex> unclaim_report(%Report{})
      {:ok, %Report{}}

  """
  def unclaim_report(%Report{} = report) do
    report
    |> Report.unclaim_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Marks the report as closed by the given user.

  ## Example

      iex> close_report(%Report{}, %User{})
      {:ok, %Report{}}

  """
  def close_report(%Report{} = report, user) do
    report
    |> Report.close_changeset(user)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Reindex all reports where the user or admin has `old_name`.

  ## Example

      iex> user_name_reindex("Administrator", "Administrator2")
      {:ok, %Req.Response{}}

  """
  def user_name_reindex(old_name, new_name) do
    data = ReportIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Report, data.query, data.set_replacements, data.replacements)
  end

  defp reindex_after_update({:ok, report}) do
    reindex_report(report)

    {:ok, report}
  end

  defp reindex_after_update(result) do
    result
  end

  @doc """
  Callback for post-transaction update.

  See `close_report_query/2` for more information and example.
  """
  def reindex_reports(report_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", report_ids])

    report_ids
  end

  @doc false
  def reindex_report(%Report{} = report) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", [report.id]])

    report
  end

  @doc false
  def perform_reindex(column, condition) do
    Report
    |> where([r], field(r, ^column) in ^condition)
    |> preload([:user, :admin])
    |> Repo.all()
    |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])
    |> Enum.map(&Search.index_document(&1, Report))
  end
end
