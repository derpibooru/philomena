defmodule Philomena.PollsTest do
  @moduledoc """
  Context-level tests for the actor-first poll editing APIs on `Philomena.Polls`:
  `load_poll_for_edit/3` and `update_poll/4`.

  These pin the shared load-and-authorize chain both functions reuse (forum
  `:show`, topic visibility, poll existence, then topic `:hide`) across the
  anonymous / regular user / moderator matrix, including the ordering quirk
  where the poll-existence check runs before the `:hide` authorization: a
  regular user on a poll-less topic answers not-found rather than unauthorized.
  The corresponding controller characterization tests pin the HTTP behavior on
  top of these results.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Polls
  alias Philomena.Polls.Poll
  alias Philomena.PollVotes
  alias Philomena.Repo

  # A visible topic (in a normal, publicly readable forum) that carries a poll,
  # the common shape both functions load through.
  defp forum_topic_poll do
    forum = forum_fixture()
    {topic, poll} = topic_with_poll_fixture(forum)
    {forum, topic, poll}
  end

  describe "edit_poll/3" do
    test "a moderator loads the poll, preloaded options, and a changeset for it" do
      moderator = moderator_user_fixture()
      {forum, topic, poll} = forum_topic_poll()

      assert {:ok, %Ecto.Changeset{data: loaded_poll}} =
               Polls.edit_poll(actor(moderator), forum.short_name, topic.slug)

      assert loaded_poll.topic.forum.id == forum.id
      assert loaded_poll.topic.id == topic.id
      assert loaded_poll.id == poll.id

      # The options are preloaded so the edit form can render existing choices:
      # a loaded list, not an unloaded association.
      assert is_list(loaded_poll.options)
      assert length(loaded_poll.options) == 2
    end

    test "an admin loads the poll" do
      admin = admin_user_fixture()
      {forum, topic, poll} = forum_topic_poll()

      assert {:ok, %Ecto.Changeset{data: loaded_poll}} =
               Polls.edit_poll(actor(admin), forum.short_name, topic.slug)

      assert loaded_poll.id == poll.id
    end

    test "a regular user is unauthorized even though the poll exists" do
      # The topic is visible, so the forum :show and topic visibility checks pass
      # and the poll load succeeds; the block on the topic :hide permission is
      # what denies a regular user.
      user = confirmed_user_fixture()
      {forum, topic, _poll} = forum_topic_poll()

      assert Polls.edit_poll(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end

    test "an anonymous actor is unauthorized" do
      # nil clears forum :show and topic visibility on normal content and the
      # poll load succeeds, but fails the topic :hide permission, so this is a
      # clean unauthorized rather than a crash on the nil actor.
      {forum, topic, _poll} = forum_topic_poll()

      assert Polls.edit_poll(actor(), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end

    test "an unknown forum is not found for a regular user" do
      assert Polls.edit_poll(actor(confirmed_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Polls.edit_poll(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) == {:error, :not_found}
    end

    test "a topic without a poll is not found for a moderator" do
      # A topic that carries no poll is not_found.
      forum = forum_fixture()
      topic = topic_fixture(forum)

      assert Polls.edit_poll(
               actor(moderator_user_fixture()),
               forum.short_name,
               topic.slug
             ) ==
               {:error, :not_found}
    end

    test "a topic without a poll is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)

      assert Polls.edit_poll(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end
  end

  describe "update_poll/4" do
    test "a moderator updates the poll title and redirect data is returned" do
      moderator = moderator_user_fixture()
      {forum, topic, poll} = forum_topic_poll()

      assert {:ok, %Poll{} = loaded_poll} =
               Polls.update_poll(actor(moderator), forum.short_name, topic.slug, %{
                 "title" => "Moderator updated title"
               })

      assert loaded_poll.topic.forum.id == forum.id
      assert loaded_poll.topic.id == topic.id
      assert Repo.reload!(poll).title == "Moderator updated title"
    end

    test "an admin updates the poll title" do
      admin = admin_user_fixture()
      {forum, topic, poll} = forum_topic_poll()

      assert {:ok, %Poll{}} =
               Polls.update_poll(actor(admin), forum.short_name, topic.slug, %{
                 "title" => "Admin updated title"
               })

      assert Repo.reload!(poll).title == "Admin updated title"
    end

    test "options can be edited before voting starts" do
      moderator = moderator_user_fixture()
      {forum, topic, poll} = forum_topic_poll()
      [option_a, option_b] = poll |> Repo.preload(:options) |> Map.fetch!(:options)

      assert {:ok, %Poll{}} =
               Polls.update_poll(actor(moderator), forum.short_name, topic.slug, %{
                 "options" => %{
                   "0" => %{"id" => option_a.id, "label" => "Renamed option"},
                   "1" => %{"id" => option_b.id, "label" => option_b.label}
                 }
               })

      assert Repo.reload!(option_a).label == "Renamed option"
    end

    test "options and vote method are immutable after voting starts" do
      moderator = moderator_user_fixture()
      voter = confirmed_user_fixture()
      {forum, topic, poll} = forum_topic_poll()
      [option_a, option_b] = poll |> Repo.preload(:options) |> Map.fetch!(:options)

      assert {:ok, _ballot} =
               PollVotes.create_votes(actor(voter), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_a.id)]
               })

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.update_poll(actor(moderator), forum.short_name, topic.slug, %{
                 "vote_method" => "multiple",
                 "options" => %{
                   "0" => %{"id" => option_a.id, "label" => "Rewritten choice"},
                   "1" => %{"id" => option_b.id, "label" => option_b.label}
                 }
               })

      assert "cannot be changed after voting has started" in errors_on(changeset).options
      assert "cannot be changed after voting has started" in errors_on(changeset).vote_method
      assert Repo.reload!(option_a).label == option_a.label
      assert Repo.reload!(poll).vote_method == "single"
    end

    test "a rejected changeset leaves the poll unchanged" do
      # Poll.changeset requires title; a blank title with another real change
      # (active_until) produces an invalid changeset with non-empty changes, so
      # it surfaces as {:error, changeset} (data containing both the loaded forum
      # and topic so the controller can re-render the edit form) rather than the
      # no-op :ignore path.
      moderator = moderator_user_fixture()
      {forum, topic, poll} = forum_topic_poll()

      assert {:error, %Ecto.Changeset{data: loaded_poll} = changeset} =
               Polls.update_poll(actor(moderator), forum.short_name, topic.slug, %{
                 "title" => "",
                 "active_until" =>
                   DateTime.utc_now(:second) |> DateTime.add(3, :day) |> DateTime.to_iso8601(),
                 "vote_method" => "single"
               })

      assert loaded_poll.topic.forum.id == forum.id
      assert loaded_poll.topic.id == topic.id
      refute changeset.valid?
      assert Repo.reload!(poll).title == "Best test option?"
    end

    test "a regular user is unauthorized and the poll is unchanged" do
      user = confirmed_user_fixture()
      {forum, topic, poll} = forum_topic_poll()

      assert Polls.update_poll(actor(user), forum.short_name, topic.slug, %{"title" => "Hijacked"}) ==
               {:error, :unauthorized}

      assert Repo.reload!(poll).title == "Best test option?"
    end

    test "an anonymous actor is unauthorized and the poll is unchanged" do
      {forum, topic, poll} = forum_topic_poll()

      assert Polls.update_poll(actor(), forum.short_name, topic.slug, %{"title" => "Hijacked"}) ==
               {:error, :unauthorized}

      assert Repo.reload!(poll).title == "Best test option?"
    end

    test "an unknown forum is not found for a regular user" do
      assert Polls.update_poll(actor(confirmed_user_fixture()), "nonexistent", "whatever", %{
               "title" => "New title"
             }) == {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Polls.update_poll(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               %{"title" => "New title"}
             ) == {:error, :not_found}
    end

    test "a topic without a poll is not found for a moderator" do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      assert Polls.update_poll(actor(moderator_user_fixture()), forum.short_name, topic.slug, %{
               "title" => "New title"
             }) == {:error, :not_found}
    end

    test "a topic without a poll is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)

      assert Polls.update_poll(actor(user), forum.short_name, topic.slug, %{
               "title" => "New title"
             }) ==
               {:error, :unauthorized}
    end
  end
end
