defmodule Philomena.ImagesConcurrencyTest do
  use Philomena.ConcurrentDataCase

  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  for interaction <- [:hide, :fave, :upvote, :downvote] do
    @interaction interaction
    test "concurrent #{@interaction}s remain idempotent and keep counters consistent" do
      user = confirmed_user_fixture()
      actor = actor(user)
      image = image_fixture(tags: "safe")

      create = fn ->
        case @interaction do
          :hide -> Images.create_image_user_hide(actor, image.id)
          :fave -> Images.create_image_fave(actor, image.id)
          :upvote -> Images.create_image_vote(actor, image.id, %{up: true})
          :downvote -> Images.create_image_vote(actor, image.id, %{up: false})
        end
      end

      results = concurrently(for _ <- 1..4, do: create)

      assert Enum.all?(results, &match?({:ok, %Image{}}, &1))

      image = Repo.get!(Image, image.id) |> Repo.preload([:hides, :faves, :upvotes, :downvotes])
      hides = if @interaction == :hide, do: 1, else: 0
      faves = if @interaction == :fave, do: 1, else: 0
      upvotes = if @interaction in [:fave, :upvote], do: 1, else: 0
      downvotes = if @interaction == :downvote, do: 1, else: 0

      assert length(image.hides) == hides
      assert length(image.faves) == faves
      assert length(image.upvotes) == upvotes
      assert length(image.downvotes) == downvotes
      assert image.hides_count == hides
      assert image.faves_count == faves
      assert image.upvotes_count == upvotes
      assert image.downvotes_count == downvotes
      assert image.score == upvotes - downvotes
      assert Repo.reload!(user).image_faves_count == faves
      assert Repo.reload!(user).image_votes_count == upvotes + downvotes
    end
  end

  test "concurrent approvals transition once and increment uploader statistics once" do
    uploader = confirmed_user_fixture()
    moderator = moderator_user_fixture()
    image = image_fixture(user_id: uploader.id, approved: false)
    initial_count = Repo.reload!(uploader).images_count

    results =
      concurrently([
        fn -> Images.create_image_approve(actor(moderator), image.id) end,
        fn -> Images.create_image_approve(actor(moderator), image.id) end
      ])

    assert Enum.count(results, &match?({:ok, %Image{}}, &1)) == 1

    assert Enum.count(
             results,
             &match?({:error, %{errors: [approved: {"must be false", []}]}}, &1)
           ) == 1

    assert Repo.get!(Image, image.id).approved
    assert Repo.reload!(uploader).images_count == initial_count + 1
    assert Repo.aggregate(ModerationLog, :count) == 1
  end

  test "concurrent source additions merge against the locked image" do
    image = image_fixture(tags: "safe")
    actors = for _ <- 1..2, do: actor(admin_user_fixture())
    sources = ["https://example.com/concurrent-one", "https://example.com/concurrent-two"]

    results =
      concurrently(
        Enum.zip(actors, sources)
        |> Enum.map(fn {actor, source} ->
          fn -> Images.update_image_sources(actor, image.id, source_attrs(source)) end
        end)
      )

    assert Enum.all?(results, &match?({:ok, %{}}, &1))
    assert source_urls(image) == Enum.sort(sources)

    assert Repo.aggregate(
             from(change in SourceChange, where: change.image_id == ^image.id),
             :count
           ) == 2
  end

  test "concurrent source addition and removal merge against the locked image" do
    base = "https://example.com/concurrent-base"
    added = "https://example.com/concurrent-added"
    image = image_fixture(tags: "safe", sources: [base])
    actors = for _ <- 1..2, do: actor(admin_user_fixture())

    results =
      concurrently([
        fn ->
          Images.update_image_sources(
            Enum.at(actors, 0),
            image.id,
            source_attrs([base], [base, added])
          )
        end,
        fn ->
          Images.update_image_sources(Enum.at(actors, 1), image.id, source_attrs([base], []))
        end
      ])

    assert Enum.all?(results, &match?({:ok, %{}}, &1))
    assert source_urls(image) == [added]

    assert Repo.aggregate(
             from(change in SourceChange, where: change.image_id == ^image.id),
             :count
           ) == 2
  end

  test "concurrent source updates are limited per actor" do
    user = confirmed_user_fixture()
    images = for _ <- 1..3, do: image_fixture(tags: "safe")
    actor = actor(user)

    results =
      concurrently(
        for {image, source} <-
              Enum.zip(images, [
                "https://example.com/limited-one",
                "https://example.com/limited-two",
                "https://example.com/limited-three"
              ]) do
          fn -> Images.update_image_sources(actor, image.id, source_attrs(source)) end
        end
      )

    assert Enum.count(results, &match?({:ok, %{}}, &1)) == 2
    assert Enum.count(results, &(&1 == {:error, :rate_limited})) == 1
  end

  test "concurrent tag additions merge against the locked image and update counts" do
    image = image_fixture(tags: "safe, initial one, initial two")
    actors = for _ <- 1..2, do: actor(admin_user_fixture())
    added_names = [unique_tag_name(), unique_tag_name()]
    old_input = "safe, initial one, initial two"

    results =
      concurrently(
        Enum.zip(actors, added_names)
        |> Enum.map(fn {actor, tag_name} ->
          fn ->
            Images.update_image_tags(
              actor,
              image.id,
              %{
                "old_tag_input" => old_input,
                "tag_input" => "#{old_input}, #{tag_name}"
              }
            )
          end
        end)
      )

    assert Enum.all?(results, &match?({:ok, %{}}, &1))
    assert tag_names(image) == Enum.sort(["safe", "initial one", "initial two" | added_names])

    added_tags = Repo.all(from(tag in Tag, where: tag.name in ^added_names))

    assert Enum.map(added_tags, & &1.images_count) |> Enum.sort() == [1, 1]

    assert Repo.aggregate(
             from(change in TagChange, where: change.image_id == ^image.id),
             :count
           ) == 2
  end

  test "concurrent tag addition and removal merge against the locked image" do
    removed_name = unique_tag_name()
    added_name = unique_tag_name()
    old_input = "safe, keep, other, #{removed_name}"
    image = image_fixture(tags: old_input)

    Repo.get_by!(Tag, name: removed_name)
    |> change(images_count: 1)
    |> Repo.update!()

    actors = for _ <- 1..2, do: actor(admin_user_fixture())

    add = fn ->
      Images.update_image_tags(
        Enum.at(actors, 0),
        image.id,
        %{"old_tag_input" => old_input, "tag_input" => "#{old_input}, #{added_name}"}
      )
    end

    remove = fn ->
      Images.update_image_tags(
        Enum.at(actors, 1),
        image.id,
        %{"old_tag_input" => old_input, "tag_input" => "safe, keep, other"}
      )
    end

    results = concurrently([add, remove])

    assert Enum.all?(results, &match?({:ok, %{}}, &1))
    assert tag_names(image) == ["keep", "other", "safe", added_name]

    assert Repo.get_by!(Tag, name: removed_name).images_count == 0
    assert Repo.get_by!(Tag, name: added_name).images_count == 1

    assert Repo.aggregate(
             from(change in TagChange, where: change.image_id == ^image.id),
             :count
           ) == 2
  end

  test "concurrent tag updates are limited per actor" do
    user = confirmed_user_fixture()

    images = for _ <- 1..3, do: image_fixture(tags: "safe, initial one, initial two")

    actor = actor(user)
    tag_names = for _ <- 1..3, do: unique_tag_name()
    old_input = "safe, initial one, initial two"

    results =
      concurrently(
        for {image, tag_name} <- Enum.zip(images, tag_names) do
          fn ->
            Images.update_image_tags(
              actor,
              image.id,
              %{
                "old_tag_input" => old_input,
                "tag_input" => "#{old_input}, #{tag_name}"
              }
            )
          end
        end
      )

    assert Enum.count(results, &match?({:ok, %{}}, &1)) == 2
    assert Enum.count(results, &(&1 == {:error, :rate_limited})) == 1
  end

  test "concurrent tag additions resolve an alias and its implications once" do
    image = image_fixture(tags: "safe, initial one, initial two")
    actors = for _ <- 1..2, do: actor(admin_user_fixture())
    alias_tag = tag_fixture(name: unique_tag_name())
    canonical_tag = tag_fixture(name: unique_tag_name())
    implied_tag = tag_fixture(name: unique_tag_name())

    canonical_tag =
      canonical_tag
      |> Repo.preload(:implied_tags)
      |> change()
      |> put_assoc(:implied_tags, [implied_tag])
      |> Repo.update!()

    alias_tag =
      alias_tag
      |> change(aliased_tag_id: canonical_tag.id)
      |> Repo.update!()

    old_input = "safe, initial one, initial two"

    results =
      concurrently(
        for actor <- actors do
          fn ->
            Images.update_image_tags(
              actor,
              image.id,
              %{
                "old_tag_input" => old_input,
                "tag_input" => "#{old_input}, #{alias_tag.name}"
              }
            )
          end
        end
      )

    assert Enum.count(results, &match?({:ok, %{}}, &1)) == 2

    assert tag_names(image) ==
             Enum.sort([
               "safe",
               "initial one",
               "initial two",
               canonical_tag.name,
               implied_tag.name
             ])

    assert Repo.aggregate(from(change in TagChange, where: change.image_id == ^image.id), :count) ==
             1
  end

  defp source_attrs(source), do: source_attrs([], [source])

  defp source_attrs(old_sources, sources) do
    %{
      "old_sources" => source_params(old_sources),
      "sources" => source_params(sources)
    }
  end

  defp source_params(sources) do
    sources
    |> Enum.with_index()
    |> Map.new(fn {source, index} -> {to_string(index), %{"source" => source}} end)
  end

  defp source_urls(image) do
    image
    |> Repo.preload(:sources, force: true)
    |> Map.fetch!(:sources)
    |> Enum.map(& &1.source)
    |> Enum.sort()
  end

  defp tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end
end
