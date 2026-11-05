defmodule PhilomenaWeb.Admin.ModNoteView do
  use PhilomenaWeb, :view

  alias Philomena.ModNotes.ModNote
  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry

  def link_to_target(%ModNote{dnp_entry: %DnpEntry{tag: tag} = dnp_entry}),
    do: link("DNP entry for #{tag.name}", to: ~p"/dnp/#{dnp_entry}")

  def link_to_target(%ModNote{report: %Report{user: nil} = report}),
    do: link("Report #{report.id}", to: ~p"/admin/reports/#{report}")

  def link_to_target(%ModNote{report: %Report{user: user} = report}),
    do:
      link("Report #{report.id} by #{user.name}",
        to: ~p"/admin/reports/#{report}"
      )

  def link_to_target(%ModNote{user: %User{} = user}),
    do: link("User #{user.name}", to: ~p"/profiles/#{user}")

  def link_to_target(%ModNote{}), do: "Item permanently deleted"

  # A new note's target lives in the changeset's changes, not its data.
  def target_label(%Ecto.Changeset{} = changeset),
    do: changeset |> Ecto.Changeset.apply_changes() |> target_label()

  def target_label(%ModNote{user_id: id}) when not is_nil(id), do: "User #{id}"
  def target_label(%ModNote{report_id: id}) when not is_nil(id), do: "Report #{id}"
  def target_label(%ModNote{dnp_entry_id: id}) when not is_nil(id), do: "DNP entry #{id}"
  def target_label(%ModNote{}), do: "unknown target"
end
