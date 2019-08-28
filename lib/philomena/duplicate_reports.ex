defmodule Philomena.DuplicateReports do
  @moduledoc """
  The DuplicateReports context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.DuplicateReports.DuplicateReport

  @doc """
  Returns the list of duplicate_reports.

  ## Examples

      iex> list_duplicate_reports()
      [%DuplicateReport{}, ...]

  """
  def list_duplicate_reports do
    Repo.all(DuplicateReport)
  end

  @doc """
  Gets a single duplicate_report.

  Raises `Ecto.NoResultsError` if the Duplicate report does not exist.

  ## Examples

      iex> get_duplicate_report!(123)
      %DuplicateReport{}

      iex> get_duplicate_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_duplicate_report!(id), do: Repo.get!(DuplicateReport, id)

  @doc """
  Creates a duplicate_report.

  ## Examples

      iex> create_duplicate_report(%{field: value})
      {:ok, %DuplicateReport{}}

      iex> create_duplicate_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_duplicate_report(attrs \\ %{}) do
    %DuplicateReport{}
    |> DuplicateReport.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a duplicate_report.

  ## Examples

      iex> update_duplicate_report(duplicate_report, %{field: new_value})
      {:ok, %DuplicateReport{}}

      iex> update_duplicate_report(duplicate_report, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_duplicate_report(%DuplicateReport{} = duplicate_report, attrs) do
    duplicate_report
    |> DuplicateReport.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a DuplicateReport.

  ## Examples

      iex> delete_duplicate_report(duplicate_report)
      {:ok, %DuplicateReport{}}

      iex> delete_duplicate_report(duplicate_report)
      {:error, %Ecto.Changeset{}}

  """
  def delete_duplicate_report(%DuplicateReport{} = duplicate_report) do
    Repo.delete(duplicate_report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking duplicate_report changes.

  ## Examples

      iex> change_duplicate_report(duplicate_report)
      %Ecto.Changeset{source: %DuplicateReport{}}

  """
  def change_duplicate_report(%DuplicateReport{} = duplicate_report) do
    DuplicateReport.changeset(duplicate_report, %{})
  end
end
