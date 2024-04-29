defmodule PhilomenaWeb.Admin.ModNoteView do
  use PhilomenaWeb, :view

  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry

  def link_to_noted_thing(%DnpEntry{tag: tag} = dnp_entry),
    do: link("DNP entry for #{tag.name}", to: ~p"/dnp/#{dnp_entry}")

  def link_to_noted_thing(%Report{user: nil} = report),
    do: link("Report #{report.id}", to: ~p"/admin/reports/#{report}")

  def link_to_noted_thing(%Report{user: user} = report),
    do:
      link("Report #{report.id} by #{user.name}",
        to: ~p"/admin/reports/#{report}"
      )

  def link_to_noted_thing(%User{} = user),
    do: link("User #{user.name}", to: ~p"/profiles/#{user}")

  def link_to_noted_thing(_notable), do: "Item permanently deleted"
end
