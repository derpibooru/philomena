defmodule Philomena.TagChangesConcurrencyTest do
  use Philomena.ConcurrentDataCase

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Repo
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags

  @base_tags "safe, base one, base two"

  defp image_tag_ids(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.id)
  end

  defp tag_change_attributes(user) do
    attribution = actor(user)

    %{
      user_id: user.id,
      ip: attribution.ip,
      fingerprint: attribution.fingerprint
    }
  end

  defp create_tag_change!(image, tag, user, added) do
    image_tag_names =
      image
      |> Repo.preload(:tags, force: true)
      |> Map.fetch!(:tags)
      |> Enum.map(& &1.name)

    old_tag_input = Enum.join(image_tag_names, ", ")

    new_tag_input =
      if added do
        Enum.join([tag.name | image_tag_names], ", ")
      else
        image_tag_names
        |> List.delete(tag.name)
        |> Enum.join(", ")
      end

    arrangement_actor = actor(%{user | bypass_rate_limits: true})

    assert {:ok, result} =
             Images.update_image_tags(
               arrangement_actor,
               image.id,
               %{"old_tag_input" => old_tag_input, "tag_input" => new_tag_input}
             )

    assert result.image.id == image.id

    Repo.one!(
      from tag_change in TagChange,
        where: tag_change.image_id == ^image.id,
        order_by: [desc: :id],
        limit: 1
    )
  end

  test "reversion removes an alias whether migration wins or loses the image lock" do
    user = confirmed_user_fixture()
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    image = image_fixture(tags: @base_tags)
    tag_change = create_tag_change!(image, source, user, true)

    source =
      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: 1)
      |> Repo.update!()

    attributes = tag_change_attributes(user)

    results =
      concurrently([
        fn -> Tags.perform_alias(source.id, target.id) end,
        fn -> TagChanges.revert_for_worker([tag_change.id], attributes) end
      ])

    assert Enum.any?(results, &(&1 == :ok))
    assert Enum.any?(results, &match?({:ok, [_]}, &1))

    ids = image_tag_ids(image)
    refute source.id in ids
    refute target.id in ids
    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == 0
  end

  test "reversion does not duplicate a source tagging while it is migrating" do
    user = confirmed_user_fixture()
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    image = image_fixture(tags: "#{@base_tags}, #{source.name}")
    removed_change = create_tag_change!(image, source, user, false)
    _later_add = create_tag_change!(image, source, user, true)

    source =
      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: 1)
      |> Repo.update!()

    attributes = tag_change_attributes(user)
    initial_change_count = Repo.aggregate(TagChange, :count)

    results =
      concurrently([
        fn -> Tags.perform_alias(source.id, target.id) end,
        fn -> TagChanges.revert_for_worker([removed_change.id], attributes) end
      ])

    assert Enum.any?(results, &(&1 == :ok))
    assert Enum.any?(results, &match?({:ok, [_]}, &1))

    ids = image_tag_ids(image)
    refute source.id in ids
    assert target.id in ids
    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == 1
    assert Repo.aggregate(TagChange, :count) == initial_change_count
  end

  test "reversion self-cancels edits that straddle an alias migration" do
    user = confirmed_user_fixture()
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    image = image_fixture(tags: @base_tags)
    added_change = create_tag_change!(image, source, user, true)

    source =
      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: 1)
      |> Repo.update!()

    assert :ok = Tags.perform_alias(source.id, target.id)
    removed_change = create_tag_change!(image, target, user, false)
    initial_change_count = Repo.aggregate(TagChange, :count)

    assert {:ok, [_first, _second]} =
             TagChanges.revert_for_worker(
               [added_change.id, removed_change.id],
               tag_change_attributes(user)
             )

    ids = image_tag_ids(image)
    refute source.id in ids
    refute target.id in ids
    assert Repo.aggregate(TagChange, :count) == initial_change_count
  end
end
