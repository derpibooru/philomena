defmodule Philomena.Forums.TopicSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "topic_subscriptions" do
    belongs_to :topic, Philomena.Forums.Topic, primary_key: true
    belongs_to :user, Philomena.Users.User, primary_key: true
  end

  @doc false
  def changeset(topic_subscription, attrs) do
    topic_subscription
    |> cast(attrs, [])
    |> validate_required([])
  end
end
