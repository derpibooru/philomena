defmodule Philomena.Forums.Visibility do
  @moduledoc """
  Database query scopes for forum hierarchy collection reads.

  These scopes intentionally mirror the `:show` rules in
  `Philomena.Users.Ability`. Collection endpoints use them before counting and
  pagination so authorization cost is bounded by the requested page.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Attribution.Actor
  alias Philomena.Posts.Post
  alias Philomena.Users.User

  @doc """
  Restricts a forum query to the access levels visible to `actor`.

  ## Examples

      iex> visible_forums(Forum, actor)
      #Ecto.Query<...>

  """
  @spec visible_forums(Ecto.Queryable.t(), Actor.t()) :: Ecto.Query.t()
  def visible_forums(queryable, %Actor{user: %User{role: role}})
      when role in ["admin", "moderator"],
      do: from(forum in queryable)

  def visible_forums(queryable, %Actor{user: %User{role: "assistant"}}),
    do: from(forum in queryable, where: forum.access_level in ["normal", "assistant"])

  def visible_forums(queryable, %Actor{}),
    do: from(forum in queryable, where: forum.access_level == "normal")

  @doc """
  Restricts a topic query to topics visible to `actor`.

  The caller remains responsible for constraining the query to authorized
  parent forums.

  ## Examples

      iex> visible_topics(Topic, actor)
      #Ecto.Query<...>

  """
  @spec visible_topics(Ecto.Queryable.t(), Actor.t()) :: Ecto.Query.t()
  def visible_topics(queryable, %Actor{user: %User{role: role}})
      when role in ["admin", "moderator", "assistant"],
      do: from(topic in queryable)

  def visible_topics(queryable, %Actor{}),
    do: from(topic in queryable, where: topic.hidden_from_users == false)

  @doc """
  Restricts a post collection query to posts visible to `actor`.

  Moderators, administrators, and topic-moderator assistants may see hidden
  posts and unavailable moderation states. Other actors receive approved,
  non-destroyed posts plus their own pending posts by account or IP. The caller
  remains responsible for constraining and authorizing the parent forum and
  topic.

  ## Examples

      iex> visible_posts(Post, actor)
      #Ecto.Query<...>

  """
  @spec visible_posts(Ecto.Queryable.t(), Actor.t()) :: Ecto.Query.t()
  def visible_posts(queryable, %Actor{} = actor) do
    queryable
    |> maybe_exclude_hidden_posts(actor)
    |> available_posts(actor)
  end

  @doc """
  Restricts a post query to approved, non-destroyed posts plus the actor's own
  pending posts. Staff with post-moderation access retain unavailable posts.

  Unlike `visible_posts/2`, this scope leaves hidden-post authorization to a
  member loader so forbidden existing records remain distinguishable from
  missing records.
  """
  @spec available_posts(Ecto.Queryable.t(), Actor.t()) :: Ecto.Query.t()
  def available_posts(queryable, %Actor{} = actor) do
    maybe_exclude_unavailable_posts(queryable, actor)
  end

  @doc """
  Generates OpenSearch boolean `filter` clauses to select posts visible to
  `actor`.

  The clauses mirror `visible_posts/2`, including forum access, hidden state,
  approval ownership, IP ownership, and destroyed-content policy.

  ## Examples

      iex> search_filters(admin_actor)
      []

      iex> search_filters(actor)
      [%{term: %{access_level: "normal"}}, ...]

  """
  @spec search_filters(Actor.t()) :: list()
  def search_filters(%Actor{} = actor) do
    search_access_filters(actor) ++ search_availability_filters(actor)
  end

  defp maybe_exclude_hidden_posts(query, actor) do
    if authorize(actor, :show, %Post{hidden_from_users: true}) == :ok do
      query
    else
      where(query, [post], post.hidden_from_users == false)
    end
  end

  defp maybe_exclude_unavailable_posts(query, actor) do
    if authorize(actor, :hide, %Post{}) == :ok do
      query
    else
      visible_to_actor(query, actor)
    end
  end

  defp visible_to_actor(query, %Actor{user: %User{id: user_id}, ip: ip}) do
    where(
      query,
      [post],
      post.destroyed_content == false and
        (post.approved == true or post.user_id == ^user_id or post.ip == ^ip)
    )
  end

  defp visible_to_actor(query, %Actor{ip: ip}) do
    where(
      query,
      [post],
      post.destroyed_content == false and (post.approved == true or post.ip == ^ip)
    )
  end

  defp search_access_filters(%Actor{user: %User{role: role}})
       when role in ["moderator", "admin"],
       do: []

  defp search_access_filters(%Actor{user: %User{role: "assistant"}}),
    do: [%{terms: %{access_level: ["normal", "assistant"]}}]

  defp search_access_filters(%Actor{}),
    do: [%{term: %{access_level: "normal"}}, %{term: %{hidden_from_users: false}}]

  defp search_availability_filters(actor) do
    if authorize(actor, :hide, %Post{}) == :ok do
      []
    else
      [
        %{term: %{destroyed_content: false}},
        %{
          bool: %{
            should: availability_should(actor)
          }
        }
      ]
    end
  end

  defp availability_should(%Actor{user: %User{id: user_id}, ip: ip}) do
    [
      %{term: %{approved: true}},
      %{term: %{true_author_id: user_id}},
      %{term: %{ip: to_string(ip)}}
    ]
  end

  defp availability_should(%Actor{ip: ip}) do
    [%{term: %{approved: true}}, %{term: %{ip: to_string(ip)}}]
  end
end
