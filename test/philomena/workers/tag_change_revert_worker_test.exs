defmodule Philomena.TagChangeRevertWorkerTest do
  use Philomena.DataCase, async: true

  # The worker runs synchronously here; only its reindex side effects are
  # dead Exq enqueues, so the tests stay Postgres-only.

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.TagChangeRevertWorker
  alias Philomena.TagChanges.TagChange

  # Images validate a 3-tag minimum, so every input keeps these on top of
  # whatever tag the test adds or removes.
  @base_tags "safe, base one, base two"

  setup do
    reset_tag_change_limits()
    user = confirmed_user_fixture()
    reset_tag_change_limits(attribution(user))
    {:ok, user: user}
  end

  defp change_tags!(image, user, old_input, new_input) do
    # These tests arrange history rather than exercise the write rate limits.
    arrangement_actor = actor(%{user | bypass_rate_limits: true})

    assert {:ok, result} =
             Images.update_image_tags(
               arrangement_actor,
               image.id,
               %{"old_tag_input" => old_input, "tag_input" => new_input}
             )

    assert result.image.id == image.id
  end

  defp full_revert!(user, batch_size) do
    TagChangeRevertWorker.perform(%{
      "user_id" => user.id,
      "attributes" => %{
        "ip" => "203.0.113.99",
        "fingerprint" => "c1774e9294a",
        "user_id" => moderator_user_fixture().id,
        "batch_size" => batch_size
      }
    })
  end

  defp image_tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
  end

  defp tag_change_count(image) do
    Repo.aggregate(from(tag_change in TagChange, where: tag_change.image_id == ^image.id), :count)
  end

  test "a full revert removes tags the user added", %{user: user} do
    image_a = image_fixture(tags: @base_tags)
    image_b = image_fixture(tags: @base_tags)
    change_tags!(image_a, user, @base_tags, "#{@base_tags}, vandal tag")
    change_tags!(image_b, user, @base_tags, "#{@base_tags}, vandal tag")

    assert tag_change_count(image_a) == 1
    assert tag_change_count(image_b) == 1

    # batch_size 1 forces the two images into separate batches.
    full_revert!(user, 1)

    refute "vandal tag" in image_tag_names(image_a)
    refute "vandal tag" in image_tag_names(image_b)
    assert tag_change_count(image_a) == 2
    assert tag_change_count(image_b) == 2
  end

  test "a full revert restores tags the user removed", %{user: user} do
    image = image_fixture(tags: "#{@base_tags}, original tag")
    change_tags!(image, user, "#{@base_tags}, original tag", @base_tags)

    full_revert!(user, 1)

    assert "original tag" in image_tag_names(image)
  end

  test "a self-canceled add/remove pair reverts to a noop", %{user: user} do
    image = image_fixture(tags: @base_tags)
    change_tags!(image, user, @base_tags, "#{@base_tags}, vandal tag")
    change_tags!(image, user, "#{@base_tags}, vandal tag", @base_tags)

    full_revert!(user, 100)

    refute "vandal tag" in image_tag_names(image)
  end

  test "a self-canceled pair stays a noop when the revert is batched", %{user: user} do
    image = image_fixture(tags: @base_tags)
    change_tags!(image, user, @base_tags, "#{@base_tags}, vandal tag")
    change_tags!(image, user, "#{@base_tags}, vandal tag", @base_tags)

    # batch_size 1 would split the two tag changes if batching ran over tag
    # change ids; batching over image ids must keep them together.
    full_revert!(user, 1)

    refute "vandal tag" in image_tag_names(image)
  end

  test "an image with more tag changes than the batch size is fully reverted", %{user: user} do
    image_a = image_fixture(tags: @base_tags)
    image_b = image_fixture(tags: @base_tags)
    change_tags!(image_a, user, @base_tags, "#{@base_tags}, vandal tag")
    change_tags!(image_b, user, @base_tags, "#{@base_tags}, vandal one")

    change_tags!(
      image_b,
      user,
      "#{@base_tags}, vandal one",
      "#{@base_tags}, vandal one, vandal two"
    )

    change_tags!(
      image_b,
      user,
      "#{@base_tags}, vandal one, vandal two",
      "#{@base_tags}, vandal two"
    )

    # image_b carries three tag changes, exceeding the batch size of 2; the
    # emitted batch queries select by image_id value, so all three must land
    # in one mass_revert call anyway.
    full_revert!(user, 2)

    refute "vandal tag" in image_tag_names(image_a)

    names_b = image_tag_names(image_b)
    refute "vandal one" in names_b
    refute "vandal two" in names_b
    assert "safe" in names_b
    assert tag_change_count(image_a) == 2
    assert tag_change_count(image_b) == 4
  end

  test "a self-canceled remove/add pair does not strip the tag", %{user: user} do
    image = image_fixture(tags: "#{@base_tags}, original tag")
    change_tags!(image, user, "#{@base_tags}, original tag", @base_tags)
    change_tags!(image, user, @base_tags, "#{@base_tags}, original tag")

    full_revert!(user, 1)

    assert "original tag" in image_tag_names(image)
  end
end
