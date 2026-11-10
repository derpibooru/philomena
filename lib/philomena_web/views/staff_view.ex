defmodule PhilomenaWeb.StaffView do
  use PhilomenaWeb, :view

  @desc_regex ~r/^([^\n]+)/

  def unavailable?(user),
    do: user.hide_default_role && user.secondary_role in [nil, ""]

  def category_title(:administrators), do: "Administrators"
  def category_title(:developers), do: "Technical Team"
  def category_title(:public_relations), do: "Public Relations"
  def category_title(:moderators), do: "Moderators"
  def category_title(:assistants), do: "Assistants"
  def category_title(:others), do: "Others"
  def category_title(:unavailable), do: "Unavailable Staff"

  def category_description(:administrators),
    do:
      "High-level staff of the site, typically handling larger-scope tasks, such as technical operation of the site or writing rules and policies."

  def category_description(:developers),
    do:
      "Developers and system administrators of the site, people who make sure the site keeps running."

  def category_description(:public_relations),
    do: "People handling public announcements, events and such."

  def category_description(:moderators),
    do:
      "The main moderation force of the site, handling a wide range of tasks from maintaining tags to making sure the rules are followed."

  def category_description(:assistants),
    do:
      "Volunteers who help us run the site by taking simpler tasks off the hands of administrators and moderators."

  def category_description(:others),
    do:
      "People associated with the site in some other way, sometimes (but not necessarily) having staff-like permissions."

  def category_description(:unavailable),
    do:
      "Privileged users who are currently inactive and do not participate in any moderation activities."

  def category_description(_), do: "This category has no description provided."

  def category_class(:administrators), do: "block--danger"
  def category_class(:developers), do: "block--warning"
  def category_class(:public_relations), do: "block--warning"
  def category_class(:moderators), do: "block--success"
  def category_class(:assistants), do: "block--assistant"
  def category_class(_), do: ""

  def staff_description(%{description: desc}) when desc not in [nil, ""] do
    [part] = Regex.run(@desc_regex, desc, capture: :all_but_first)
    String.slice(part, 0, 240)
  end

  def staff_description(_),
    do: "This person didn't provide any description, they seem to need a hug."
end
