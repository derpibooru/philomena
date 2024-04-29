defmodule PhilomenaWeb.ReportView do
  use PhilomenaWeb, :view

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery
  alias Philomena.Posts.Post
  alias Philomena.Users.User

  import Ecto.Changeset

  def report_categories do
    [
      "Rule #0: Namecalling, trolling, discrimination": "Rule #0",
      "Rule #1: DNP, content theft, pay content, trace/bad edit": "Rule #1",
      "Rule #2: Bad tagging/sourcing": "Rule #2",
      "Rule #3: Image not MLP-related/obligatory pony": "Rule #3",
      "Rule #4: Whining about filterable content": "Rule #4",
      "Rule #5: Underage+human/anthro-looking porn": "Rule #5",
      "Rule #6: Spam, off-topic, or general site abuse": "Rule #6",
      "Rule #7: Above topic rating (NOT swear words)": "Rule #7",
      "Rule #8: Privacy violation": "Rule #8",
      "Rule #9: Commissions": "Rule #9",
      "Rule #n: Spirit of the rules": "Rule #n",
      "Other (please explain)": "Other",
      "Takedown request": "Takedown request"
    ]
  end

  def image?(changeset), do: get_field(changeset, :reportable_type) == "Image"
  def conversation?(changeset), do: get_field(changeset, :reportable_type) == "Conversation"

  def report_row_class(%{state: "closed"}), do: "success"
  def report_row_class(%{state: "in_progress"}), do: "warning"
  def report_row_class(_report), do: "danger"

  def pretty_state(%{state: "closed"}), do: "Closed"
  def pretty_state(%{state: "in_progress"}), do: "In progress"
  def pretty_state(%{state: "claimed"}), do: "Claimed"
  def pretty_state(_report), do: "Open"

  def link_to_reported_thing(%Image{} = r),
    do: link("Image >>#{r.id}", to: ~p"/images/#{r}")

  def link_to_reported_thing(%Comment{} = r),
    do:
      link("Comment on image >>#{r.image.id}",
        to: ~p"/images/#{r.image}" <> "#comment_#{r.id}"
      )

  def link_to_reported_thing(%Conversation{} = r),
    do:
      link("Conversation between #{r.from.name} and #{r.to.name}",
        to: ~p"/conversations/#{r}"
      )

  def link_to_reported_thing(%Commission{} = r),
    do:
      link("#{r.user.name}'s commission page",
        to: ~p"/profiles/#{r.user}/commission"
      )

  def link_to_reported_thing(%Gallery{} = r),
    do: link("Gallery '#{r.title}' by #{r.creator.name}", to: ~p"/galleries/#{r}")

  def link_to_reported_thing(%Post{} = r),
    do:
      link("Post in #{r.topic.title}",
        to:
          ~p"/forums/#{r.topic.forum}/topics/#{r.topic}?#{[post_id: r.id]}" <>
            "#post_#{r.id}"
      )

  def link_to_reported_thing(%User{} = r),
    do: link("User '#{r.name}'", to: ~p"/profiles/#{r}")

  def link_to_reported_thing(_reportable) do
    "Reported item permanently destroyed."
  end
end
