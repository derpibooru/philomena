defmodule Philomena.Forums do
  @moduledoc """
  The Forums context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Forums.Forum

  @doc """
  Returns the list of forums.

  ## Examples

      iex> list_forums()
      [%Forum{}, ...]

  """
  def list_forums do
    Repo.all(Forum)
  end

  @doc """
  Gets a single forum.

  Raises `Ecto.NoResultsError` if the Forum does not exist.

  ## Examples

      iex> get_forum!(123)
      %Forum{}

      iex> get_forum!(456)
      ** (Ecto.NoResultsError)

  """
  def get_forum!(id), do: Repo.get!(Forum, id)

  @doc """
  Creates a forum.

  ## Examples

      iex> create_forum(%{field: value})
      {:ok, %Forum{}}

      iex> create_forum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_forum(attrs \\ %{}) do
    %Forum{}
    |> Forum.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a forum.

  ## Examples

      iex> update_forum(forum, %{field: new_value})
      {:ok, %Forum{}}

      iex> update_forum(forum, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_forum(%Forum{} = forum, attrs) do
    forum
    |> Forum.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Forum.

  ## Examples

      iex> delete_forum(forum)
      {:ok, %Forum{}}

      iex> delete_forum(forum)
      {:error, %Ecto.Changeset{}}

  """
  def delete_forum(%Forum{} = forum) do
    Repo.delete(forum)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking forum changes.

  ## Examples

      iex> change_forum(forum)
      %Ecto.Changeset{source: %Forum{}}

  """
  def change_forum(%Forum{} = forum) do
    Forum.changeset(forum, %{})
  end

  alias Philomena.Forums.Topic

  @doc """
  Returns the list of topics.

  ## Examples

      iex> list_topics()
      [%Topic{}, ...]

  """
  def list_topics do
    Repo.all(Topic)
  end

  @doc """
  Gets a single topic.

  Raises `Ecto.NoResultsError` if the Topic does not exist.

  ## Examples

      iex> get_topic!(123)
      %Topic{}

      iex> get_topic!(456)
      ** (Ecto.NoResultsError)

  """
  def get_topic!(id), do: Repo.get!(Topic, id)

  @doc """
  Creates a topic.

  ## Examples

      iex> create_topic(%{field: value})
      {:ok, %Topic{}}

      iex> create_topic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_topic(attrs \\ %{}) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a topic.

  ## Examples

      iex> update_topic(topic, %{field: new_value})
      {:ok, %Topic{}}

      iex> update_topic(topic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_topic(%Topic{} = topic, attrs) do
    topic
    |> Topic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Topic.

  ## Examples

      iex> delete_topic(topic)
      {:ok, %Topic{}}

      iex> delete_topic(topic)
      {:error, %Ecto.Changeset{}}

  """
  def delete_topic(%Topic{} = topic) do
    Repo.delete(topic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking topic changes.

  ## Examples

      iex> change_topic(topic)
      %Ecto.Changeset{source: %Topic{}}

  """
  def change_topic(%Topic{} = topic) do
    Topic.changeset(topic, %{})
  end

  alias Philomena.Forums.Post

  @doc """
  Returns the list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Repo.all(Post)
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{source: %Post{}}

  """
  def change_post(%Post{} = post) do
    Post.changeset(post, %{})
  end

  alias Philomena.Forums.Subscription

  @doc """
  Returns the list of forum_subscriptions.

  ## Examples

      iex> list_forum_subscriptions()
      [%Subscription{}, ...]

  """
  def list_forum_subscriptions do
    Repo.all(Subscription)
  end

  @doc """
  Gets a single subscription.

  Raises `Ecto.NoResultsError` if the Subscription does not exist.

  ## Examples

      iex> get_subscription!(123)
      %Subscription{}

      iex> get_subscription!(456)
      ** (Ecto.NoResultsError)

  """
  def get_subscription!(id), do: Repo.get!(Subscription, id)

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{field: value})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subscription.

  ## Examples

      iex> update_subscription(subscription, %{field: new_value})
      {:ok, %Subscription{}}

      iex> update_subscription(subscription, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Subscription.

  ## Examples

      iex> delete_subscription(subscription)
      {:ok, %Subscription{}}

      iex> delete_subscription(subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subscription(%Subscription{} = subscription) do
    Repo.delete(subscription)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subscription changes.

  ## Examples

      iex> change_subscription(subscription)
      %Ecto.Changeset{source: %Subscription{}}

  """
  def change_subscription(%Subscription{} = subscription) do
    Subscription.changeset(subscription, %{})
  end

  alias Philomena.Forums.Polls

  @doc """
  Returns the list of polls.

  ## Examples

      iex> list_polls()
      [%Polls{}, ...]

  """
  def list_polls do
    Repo.all(Polls)
  end

  @doc """
  Gets a single polls.

  Raises `Ecto.NoResultsError` if the Polls does not exist.

  ## Examples

      iex> get_polls!(123)
      %Polls{}

      iex> get_polls!(456)
      ** (Ecto.NoResultsError)

  """
  def get_polls!(id), do: Repo.get!(Polls, id)

  @doc """
  Creates a polls.

  ## Examples

      iex> create_polls(%{field: value})
      {:ok, %Polls{}}

      iex> create_polls(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_polls(attrs \\ %{}) do
    %Polls{}
    |> Polls.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a polls.

  ## Examples

      iex> update_polls(polls, %{field: new_value})
      {:ok, %Polls{}}

      iex> update_polls(polls, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_polls(%Polls{} = polls, attrs) do
    polls
    |> Polls.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Polls.

  ## Examples

      iex> delete_polls(polls)
      {:ok, %Polls{}}

      iex> delete_polls(polls)
      {:error, %Ecto.Changeset{}}

  """
  def delete_polls(%Polls{} = polls) do
    Repo.delete(polls)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking polls changes.

  ## Examples

      iex> change_polls(polls)
      %Ecto.Changeset{source: %Polls{}}

  """
  def change_polls(%Polls{} = polls) do
    Polls.changeset(polls, %{})
  end

  alias Philomena.Forums.PollVote

  @doc """
  Returns the list of poll_votes.

  ## Examples

      iex> list_poll_votes()
      [%PollVote{}, ...]

  """
  def list_poll_votes do
    Repo.all(PollVote)
  end

  @doc """
  Gets a single poll_vote.

  Raises `Ecto.NoResultsError` if the Poll vote does not exist.

  ## Examples

      iex> get_poll_vote!(123)
      %PollVote{}

      iex> get_poll_vote!(456)
      ** (Ecto.NoResultsError)

  """
  def get_poll_vote!(id), do: Repo.get!(PollVote, id)

  @doc """
  Creates a poll_vote.

  ## Examples

      iex> create_poll_vote(%{field: value})
      {:ok, %PollVote{}}

      iex> create_poll_vote(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_poll_vote(attrs \\ %{}) do
    %PollVote{}
    |> PollVote.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a poll_vote.

  ## Examples

      iex> update_poll_vote(poll_vote, %{field: new_value})
      {:ok, %PollVote{}}

      iex> update_poll_vote(poll_vote, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_poll_vote(%PollVote{} = poll_vote, attrs) do
    poll_vote
    |> PollVote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PollVote.

  ## Examples

      iex> delete_poll_vote(poll_vote)
      {:ok, %PollVote{}}

      iex> delete_poll_vote(poll_vote)
      {:error, %Ecto.Changeset{}}

  """
  def delete_poll_vote(%PollVote{} = poll_vote) do
    Repo.delete(poll_vote)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking poll_vote changes.

  ## Examples

      iex> change_poll_vote(poll_vote)
      %Ecto.Changeset{source: %PollVote{}}

  """
  def change_poll_vote(%PollVote{} = poll_vote) do
    PollVote.changeset(poll_vote, %{})
  end
end
