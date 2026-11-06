defmodule Philomena.Comments.Visibility do
  @moduledoc """
  Database query scopes for comment collection reads.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization

  alias Philomena.Attribution.Actor
  alias Philomena.Comments.Comment
  alias Philomena.Filters.Filter
  alias Philomena.Images.Image
  alias Philomena.Users.User

  defp authorized?(%Actor{} = actor, action, subject),
    do: authorize(actor, action, subject) == :ok

  defp visibility_policy(%Actor{} = actor, allow_privileged?) do
    %{
      show_hidden_comments?:
        allow_privileged? and
          authorized?(actor, :show, %Comment{hidden_from_users: true}),
      show_hidden_images?:
        allow_privileged? and authorized?(actor, :show, %Image{hidden_from_users: true}),
      show_destroyed_comments?: allow_privileged? and authorized?(actor, :delete, %Comment{}),
      show_unapproved_comments?: allow_privileged? and authorized?(actor, :approve, %Comment{}),
      show_unapproved_images?: allow_privileged? and authorized?(actor, :approve, %Image{})
    }
  end

  defp filter_destroyed_comments(query, true), do: query

  defp filter_destroyed_comments(query, false),
    do: where(query, [comment], not comment.destroyed_content)

  defp filter_non_approved(query, _user, true), do: query

  defp filter_non_approved(query, %User{id: user_id}, false),
    do: where(query, [comment], comment.approved or comment.user_id == ^user_id)

  defp filter_non_approved(query, _user, false),
    do: where(query, [comment], comment.approved)

  defp exclude_hidden_comments(filters, true), do: filters

  defp exclude_hidden_comments(filters, false),
    do: [%{term: %{hidden_from_users: true}} | filters]

  defp exclude_hidden_images(filters, true), do: filters

  defp exclude_hidden_images(filters, false),
    do: [%{term: %{"image.hidden_from_users" => true}} | filters]

  defp exclude_destroyed_comments(filters, true), do: filters

  defp exclude_destroyed_comments(filters, false),
    do: [%{term: %{destroyed_content: true}} | filters]

  defp exclude_unapproved_comments(filters, _user, true), do: filters

  defp exclude_unapproved_comments(filters, %User{id: user_id}, false) do
    [
      %{
        bool: %{
          must: [%{term: %{approved: false}}],
          must_not: [%{term: %{true_author_id: user_id}}]
        }
      }
      | filters
    ]
  end

  defp exclude_unapproved_comments(filters, _user, false),
    do: [%{term: %{approved: false}} | filters]

  defp exclude_unapproved_images(filters, true), do: filters

  defp exclude_unapproved_images(filters, false),
    do: [%{term: %{"image.approved" => false}} | filters]

  @doc """
  Restricts a comment query to comments shown in an image's comment thread
  for `actor`.

  Hidden comments stay in the thread so their deletion reason can be shown.
  Destroyed comments are visible only to actors who can destroy comments, and
  unapproved comments only to approvers and their author.

  ## Examples

      iex> visible_comments(Comment, actor)
      #Ecto.Query<...>

  """
  @spec visible_comments(Ecto.Queryable.t(), Actor.t()) :: Ecto.Query.t()
  def visible_comments(queryable, %Actor{} = actor) do
    policy = visibility_policy(actor, true)

    queryable
    |> filter_destroyed_comments(policy.show_destroyed_comments?)
    |> filter_non_approved(actor.user, policy.show_unapproved_comments?)
  end

  @doc """
  Generates an OpenSearch boolean `must_not` clause to select comments
  visible to `actor`.

  Moderators, administrators, and image moderator assistants can see hidden
  comments. `allow_privileged?` determines whether any may be returned.

  ## Examples

      iex> search_exclusions(admin, filter, true)
      [%{terms: %{"image.tag_ids" => []}}]

      iex> search_exclusions(user, filter, true)
      [%{term: %{hidden_from_users: true}}, ...]

  """
  @spec search_exclusions(Actor.t(), Filter.t(), boolean()) :: list()
  def search_exclusions(%Actor{user: user} = actor, %Filter{} = filter, allow_privileged?) do
    policy = visibility_policy(actor, allow_privileged?)

    [%{terms: %{"image.tag_ids" => filter.hidden_tag_ids}}]
    |> exclude_hidden_comments(policy.show_hidden_comments?)
    |> exclude_hidden_images(policy.show_hidden_images?)
    |> exclude_destroyed_comments(policy.show_destroyed_comments?)
    |> exclude_unapproved_comments(user, policy.show_unapproved_comments?)
    |> exclude_unapproved_images(policy.show_unapproved_images?)
  end
end
