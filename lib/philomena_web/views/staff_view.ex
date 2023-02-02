defmodule PhilomenaWeb.StaffView do
  use PhilomenaWeb, :view

  @desc_regex ~r/^([^\n]+)/

  def unavailable?(user),
    do: user.hide_default_role && user.secondary_role in [nil, ""]

  def category_description("Administrators"),
    do:
      "High-level staff of the site, typically handling larger-scope tasks, such as technical operation of the site or writing rules and policies."

  def category_description("Technical Team"),
    do:
      "Developers and system administrators of the site, people who make sure the site keeps running."

  def category_description("Public Relations"),
    do: "People handling public announcements, events and such."

  def category_description("Moderators"),
    do:
      "The main moderation force of the site, handling a wide range of tasks from maintaining tags to making sure the rules are followed."

  def category_description("Assistants"),
    do:
      "Volunteers who help us run the site by taking simpler tasks off the hands of administrators and moderators."

  def category_description("Others"),
    do:
      "People associated with the site in some other way, sometimes (but not necessarily) having staff-like permissions."

  def category_description("Unavailable Staff"),
    do:
      "Privileged users who are currently inactive and do not participate in any moderation activities."

  def category_description(_), do: "This category has no description provided."

  def category_class("Administrators"), do: "block--danger"
  def category_class("Technical Team"), do: "block--warning"
  def category_class("Public Relations"), do: "block--warning"
  def category_class("Moderators"), do: "block--success"
  def category_class("Assistants"), do: "block--assistant"
  def category_class(_), do: ""

  def staff_description(%{description: desc}) when desc not in [nil, ""] do
    [part] = Regex.run(@desc_regex, desc, capture: :all_but_first)
    String.slice(part, 0, 240)
  end

  def staff_description(_),
    do: "This person didn't provide any description, they seem to need a hug."
end
