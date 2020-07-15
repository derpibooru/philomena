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
      "Rule 1: Breach of conduct": "Rule 1",
      "Rule 1a: Impersonation": "Rule 1a",
      "Rule 1b: Breach of Privacy": "Rule 1b",
      "Rule 1d: Off-topic, derailing, shitposting": "Rule 1d",
      "Rule 1e: Roleplay": "Rule 1e",
      "Rule 2a: Unrelated to MLP": "Rule 2a",
      "Rule 2b: Hateful content": "Rule 2b",
      "Rule 2c: Underage porn": "Rule 2c",
      "Rule 2d: Illegal content": "Rule 2d",
      "Rule 2e: Banned topic": "Rule 2e",
      "Rule 3a: Forcing opinion": "Rule 3a",
      "Rule 3b: NSFW content in non-filterable medium": "Rule 3b",
      "Rule 3c: Mistagging": "Rule 3c",
      "Rule 4a: Incorrect sourcing": "Rule 4a",
      "Rule 4b: Breach of DNP": "Rule 4b",
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

  def link_to_reported_thing(conn, %Image{} = r),
    do: link("Image >>#{r.id}", to: Routes.image_path(conn, :show, r))

  def link_to_reported_thing(conn, %Comment{} = r),
    do:
      link("Comment on image >>#{r.image.id}",
        to: Routes.image_path(conn, :show, r.image) <> "#comment_#{r.id}"
      )

  def link_to_reported_thing(conn, %Conversation{} = r),
    do:
      link("Conversation between #{r.from.name} and #{r.to.name}",
        to: Routes.conversation_path(conn, :show, r)
      )

  def link_to_reported_thing(conn, %Commission{} = r),
    do:
      link("#{r.user.name}'s commission page",
        to: Routes.profile_commission_path(conn, :show, r.user)
      )

  def link_to_reported_thing(conn, %Gallery{} = r),
    do: link("Gallery '#{r.title}' by #{r.creator.name}", to: Routes.gallery_path(conn, :show, r))

  def link_to_reported_thing(conn, %Post{} = r),
    do:
      link("Post in #{r.topic.title}",
        to:
          Routes.forum_topic_path(conn, :show, r.topic.forum, r.topic, post_id: r.id) <>
            "#post_#{r.id}"
      )

  def link_to_reported_thing(conn, %User{} = r),
    do: link("User '#{r.name}'", to: Routes.profile_path(conn, :show, r))

  def link_to_reported_thing(_conn, _reportable) do
    "Reported item permanently destroyed."
  end
end
