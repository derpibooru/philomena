defmodule Philomena.ReportsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Reports` context.
  """

  import Philomena.AttributionFixtures

  alias Philomena.Reports
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Posts.Post
  alias Philomena.Repo
  alias Philomena.Users.User

  @doc """
  Creates a report against the target named by `target`, a one-entry keyword
  list of the target foreign key column and its id (e.g. `image_id: image.id`),
  reported by `user` (anonymous attribution when `nil`).

  Reports require a non-internal rule; when `"rule_id"` is not given, a
  fresh `Philomena.RulesFixtures.rule_fixture/1` is created for it.
  """
  def report_fixture(user \\ nil, attrs \\ %{}, target) do
    attrs =
      attrs
      |> Enum.into(%{
        "reason" => "Test report reason",
        "user_agent" => "Test Browser/1.0"
      })
      |> Map.put_new_lazy("rule_id", fn -> Philomena.RulesFixtures.rule_fixture().id end)

    {:ok, report} = Reports.create_report(actor(user), target_locator(target), attrs)

    report
  end

  defp target_locator(image_id: id), do: {:image, id}
  defp target_locator(gallery_id: id), do: {:gallery, id}

  defp target_locator(reported_user_id: id) do
    {:user, Repo.get!(User, id).slug}
  end

  defp target_locator(commission_id: id) do
    commission = Repo.get!(Commission, id) |> Repo.preload(:user)
    {:commission, commission.user.slug}
  end

  defp target_locator(conversation_id: id) do
    {:conversation, Repo.get!(Conversation, id).slug}
  end

  defp target_locator(comment_id: id) do
    comment = Repo.get!(Comment, id)
    {:comment, comment.image_id, id}
  end

  defp target_locator(post_id: id) do
    post = Repo.get!(Post, id) |> Repo.preload(topic: :forum)
    {:post, post.topic.forum.short_name, post.topic.slug, id}
  end
end
