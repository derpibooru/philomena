defmodule Philomena.Reports.ReportPage do
  @moduledoc """
  The assembled admin report listing: the searched reports, plus the viewing
  admin's own open reports and the open system reports.
  """

  alias Philomena.Reports.Report

  @enforce_keys [:reports, :my_reports, :system_reports]
  defstruct [:reports, :my_reports, :system_reports]

  @type t :: %__MODULE__{
          reports: Scrivener.Page.t(),
          my_reports: [Report.t()],
          system_reports: [Report.t()]
        }
end
