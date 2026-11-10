defmodule Philomena.TopicsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Topics` context.
  """

  import Ecto.Query

  import Philomena.AttributionFixtures
  import Philomena.UsersFixtures

  alias Philomena.Polls.Poll
  alias Philomena.Repo
  alias Philomena.Topics

  def unique_topic_title, do: "Test Topic #{System.unique_integer([:positive])}"

  @doc """
  Creates a topic (with its required first post) in `forum`, authored by
  `user` (an anonymously displayed topic when `nil`).

  `attrs` are merged into the string-keyed params map the way the topic
  controller would submit them; pass `"posts" => %{"0" => %{"body" => ...}}`
  to override the first post body.

  Returns the topic with `posts: [first_post]` loaded.
  """
  def topic_fixture(forum, user \\ nil, attrs \\ %{}) do
    anonymous? = is_nil(user)

    user =
      if anonymous? do
        user = Repo.preload(admin_user_fixture(), :settings)
        put_in(user.settings.watch_on_new_topic, false)
      else
        user
      end

    attrs =
      Enum.into(attrs, %{
        "title" => unique_topic_title(),
        "anonymous" => to_string(anonymous?),
        "posts" => %{"0" => %{"body" => "Test topic body"}}
      })

    {:ok, %{topic: topic}} =
      Topics.create_topic(actor(user, ip: random_ip()), forum.short_name, attrs)

    topic
  end

  @doc """
  Creates a topic in `forum` (authored by `user`, anonymous when `nil`) that
  carries a poll, and returns `{topic, poll}`.

  `poll_attrs` are merged into the poll params the topic controller would
  submit; the defaults produce a valid single-choice poll with two options.
  """
  def topic_with_poll_fixture(forum, user \\ nil, poll_attrs \\ %{}) do
    poll_params =
      Enum.into(poll_attrs, %{
        "title" => "Best test option?",
        "active_until" => DateTime.add(DateTime.utc_now(:second), 7, :day),
        "vote_method" => "single",
        "options" => %{"0" => %{"label" => "Option A"}, "1" => %{"label" => "Option B"}}
      })

    topic = topic_fixture(forum, user, %{"poll" => poll_params})
    poll = Repo.one!(from p in Poll, where: p.topic_id == ^topic.id)

    {topic, poll}
  end
end
