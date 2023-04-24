defmodule PhilomenaWeb.Admin.ModNoteView do
  use PhilomenaWeb, :view

  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry

  def link_to_noted_thing(conn, %DnpEntry{tag: tag} = dnp_entry),
    do: link("DNP entry for #{tag.name}", to: Routes.dnp_entry_path(conn, :show, dnp_entry))

  def link_to_noted_thing(conn, %Report{user: nil} = report),
    do: link("Report #{report.id}", to: Routes.admin_report_path(conn, :show, report))

  def link_to_noted_thing(conn, %Report{user: user} = report),
    do:
      link("Report #{report.id} by #{user.name}",
        to: Routes.admin_report_path(conn, :show, report)
      )

  def link_to_noted_thing(conn, %User{} = user),
    do: link("User #{user.name}", to: Routes.profile_path(conn, :show, user))

  def link_to_noted_thing(_conn, _notable), do: "Item permanently deleted"
end
