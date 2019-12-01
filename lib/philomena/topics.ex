defmodule Philomena.Topics do
  @moduledoc """
  The Topics context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Topics.Topic
  alias Philomena.Forums.Forum
  alias Philomena.Notifications

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
  def create_topic(forum, attribution, attrs \\ %{}) do
    topic =
      %Topic{}
      |> Topic.creation_changeset(attrs, forum, attribution)

    Multi.new
    |> Multi.insert(:topic, topic)
    |> Multi.run(:update_topic, fn repo, %{topic: topic} ->
      {count, nil} =
        Topic
        |> where(id: ^topic.id)
        |> repo.update_all(set: [last_post_id: hd(topic.posts).id])

      {:ok, count}
    end)
    |> Multi.run(:update_forum, fn repo, %{topic: topic} ->
      {count, nil} =
        Forum
        |> where(id: ^topic.forum_id)
        |> repo.update_all(inc: [post_count: 1], set: [last_post_id: hd(topic.posts).id])

      {:ok, count}
    end)
    |> Multi.run(:subscribe, fn _repo, %{topic: topic} ->
      create_subscription(topic, attribution[:user])
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  def notify_topic(topic) do
    spawn fn ->
      forum =
        topic
        |> Repo.preload(:forum)
        |> Map.fetch!(:forum)

      subscriptions =
        forum
        |> Repo.preload(:subscriptions)
        |> Map.fetch!(:subscriptions)

      Notifications.notify(
        topic,
        subscriptions,
        %{
          actor_id: forum.id,
          actor_type: "Forum",
          actor_child_id: topic.id,
          actor_child_type: "Topic",
          action: "posted a new topic in"
        }
      )
    end

    topic
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

  alias Philomena.Topics.Subscription

  def subscribed?(_topic, nil), do: false
  def subscribed?(topic, user) do
    Subscription
    |> where(topic_id: ^topic.id, user_id: ^user.id)
    |> Repo.exists?()
  end

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{field: value})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(_topic, nil), do: {:ok, nil}
  def create_subscription(topic, user) do
    %Subscription{topic_id: topic.id, user_id: user.id}
    |> Subscription.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Deletes a Subscription.

  ## Examples

      iex> delete_subscription(subscription)
      {:ok, %Subscription{}}

      iex> delete_subscription(subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subscription(topic, user) do
    clear_notification(topic, user)

    %Subscription{topic_id: topic.id, user_id: user.id}
    |> Repo.delete()
  end

  def clear_notification(_topic, nil), do: nil
  def clear_notification(topic, user) do
    Notifications.delete_unread_notification("Topic", topic.id, user)
  end
end
