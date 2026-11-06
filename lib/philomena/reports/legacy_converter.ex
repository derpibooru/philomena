defmodule Philomena.Reports.LegacyConverter do
  @moduledoc """
  Converts legacy report reasons to their structured rule and reason fields.
  """

  import Ecto.Query

  alias PhilomenaQuery.Batch
  alias Philomena.Reports.Report
  alias Philomena.Rules
  alias Philomena.Rules.Rule
  alias Philomena.Reports

  # Legacy categories whose rule carries a longer name.
  @category_rule_names %{"Other" => "Other (please explain)"}

  # Legacy reasons are "<category>: <details>", or only the category when the
  # reporter gave no details.
  defp convert_report(%Report{rule: %Rule{name: "Legacy"}, reason: reason} = report, rules) do
    [category | details] = String.split(reason, ": ", parts: 2)
    details = details |> Enum.join() |> String.trim()

    with {:ok, rule} <- Map.fetch(rules, Map.get(@category_rule_names, category, category)) do
      Reports.convert_legacy_report!(report, if(details == "", do: reason, else: details), rule)
    end
  end

  defp convert_report(_report, _rules), do: :ok

  @doc """
  Converts legacy report reasons to their structured rule and reason fields.

  A report keeps the `Legacy` rule and its full reason when its category names
  no rule.

  ## Examples

      iex> convert_reports!()
      :ok

  """
  @spec convert_reports!() :: :ok
  def convert_reports! do
    rules = Map.new(Rules.list_rules(), &{&1.name, &1})

    Report
    |> preload(:rule)
    |> Batch.records(batch_size: 128)
    |> Enum.each(&convert_report(&1, rules))
  end
end
