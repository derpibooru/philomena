defmodule Philomena.TagsConcurrencyTest do
  use Philomena.ConcurrentDataCase
  use Patch

  import Philomena.TagsFixtures
  import Philomena.DnpEntriesFixtures
  import Philomena.FiltersFixtures

  alias Philomena.Images
  alias Philomena.DnpEntries
  alias Philomena.Filters
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  test "overlapping vectorized counter updates complete in primary-key lock order" do
    tags = Enum.map(1..4, fn index -> tag_fixture(name: "counter tag #{index}") end)
    ascending_ids = Enum.map(tags, & &1.id)
    descending_ids = Enum.reverse(ascending_ids)

    results =
      concurrently(
        for tag_ids <- List.duplicate(ascending_ids, 4) ++ List.duplicate(descending_ids, 4) do
          fn ->
            Repo.transaction(fn ->
              Tags.update_image_counts(Repo, 1, tag_ids)
            end)
          end
        end
      )

    assert Enum.all?(results, &(&1 == {:ok, length(tags)}))

    counts =
      Tag
      |> where([tag], tag.id in ^ascending_ids)
      |> order_by(:id)
      |> select([tag], tag.images_count)
      |> Repo.all()

    assert counts == List.duplicate(length(results), length(tags))
  end

  test "concurrent canonicalization creates one tag and returns it to every transaction" do
    name = unique_tag_name()

    results =
      concurrently(
        for _ <- 1..8 do
          fn ->
            Multi.new()
            |> Tags.put_canonicalize_tag_name_sets([
              {:tags, [name], allow_insert_new?: true}
            ])
            |> Multi.transact()
          end
        end
      )

    assert Enum.all?(results, &match?({:ok, %{canonical_tags: %{tags: [%Tag{name: ^name}]}}}, &1))
    assert Repo.aggregate(from(tag in Tag, where: tag.name == ^name), :count) == 1
  end

  test "concurrent alias requests for one source commit only one target" do
    source = tag_fixture(name: unique_tag_name())
    targets = for _ <- 1..2, do: tag_fixture(name: unique_tag_name())
    actors = for _ <- 1..2, do: actor(admin_user_fixture())

    results =
      concurrently(
        Enum.zip(actors, targets)
        |> Enum.map(fn {actor, target} ->
          fn -> Tags.update_tag_alias(actor, source.slug, %{"target_tag" => target.name}) end
        end)
      )

    assert Enum.count(results, &match?({:ok, %Tag{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
    assert Repo.reload!(source).aliased_tag_id in Enum.map(targets, & &1.id)
    assert Repo.aggregate(ModerationLog, :count) == 1
  end

  test "concurrent alias workers migrate each image tagging once" do
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    images = for _ <- 1..4, do: image_fixture(tags: "safe, #{source.name}")

    source =
      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: length(images))
      |> Repo.update!()

    results =
      concurrently(
        for _ <- 1..4 do
          fn -> Tags.perform_alias(source.id, target.id) end
        end
      )

    assert results == List.duplicate(:ok, 4)

    for image <- images do
      tag_ids =
        image
        |> Repo.preload(:tags, force: true)
        |> Map.fetch!(:tags)
        |> Enum.map(& &1.id)

      assert target.id in tag_ids
      refute source.id in tag_ids
    end

    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == length(images)
  end

  test "a filter update racing an alias stores the canonical tag" do
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    user = confirmed_user_fixture()
    filter = filter_fixture(user)

    results =
      concurrently([
        fn ->
          Tags.update_tag_alias(actor(admin_user_fixture()), source.slug, %{
            "target_tag" => target.name
          })
        end,
        fn ->
          Filters.update_filter(actor(user), filter.id, %{
            "hidden_tag_list" => source.name,
            "spoilered_tag_list" => ""
          })
        end
      ])

    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert Repo.reload!(filter).hidden_tag_ids == [target.id]
  end

  test "a DNP update racing an alias stores the canonical tag" do
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    moderator = moderator_user_fixture()
    entry = dnp_entry_fixture(moderator, source)

    results =
      concurrently([
        fn ->
          Tags.update_tag_alias(actor(admin_user_fixture()), source.slug, %{
            "target_tag" => target.name
          })
        end,
        fn ->
          DnpEntries.update_dnp_entry(
            actor(moderator),
            entry.id,
            %{
              "tag_id" => to_string(source.id),
              "dnp_type" => "No Edits",
              "reason" => "Updated reason"
            }
          )
        end
      ])

    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert Repo.reload!(entry).tag_id == target.id
  end

  test "an alias worker and an image tag edit serialize on the image row" do
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    added = unique_tag_name()
    image = image_fixture(tags: "safe, #{source.name}")

    source =
      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: 1)
      |> Repo.update!()

    results =
      concurrently([
        fn -> Tags.perform_alias(source.id, target.id) end,
        fn ->
          Images.update_image_tags(
            actor(admin_user_fixture()),
            image.id,
            %{
              "old_tag_input" => "safe, #{source.name}",
              "tag_input" => "safe, #{source.name}, #{added}"
            }
          )
        end
      ])

    assert Enum.count(results, &(&1 == :ok)) == 1
    assert Enum.count(results, &match?({:ok, %{}}, &1)) == 1

    tag_ids =
      image
      |> Repo.preload(:tags, force: true)
      |> Map.fetch!(:tags)
      |> Enum.map(& &1.id)

    assert target.id in tag_ids
    refute source.id in tag_ids
    assert Enum.any?(Repo.preload(image, :tags, force: true).tags, &(&1.name == added))
    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == 1
  end

  test "an alias worker and a batch tag edit serialize on the image row" do
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())
    image = image_fixture(tags: "safe, #{source.name}")

    source =
      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: 1)
      |> Repo.update!()

    results =
      concurrently([
        fn -> Tags.perform_alias(source.id, target.id) end,
        fn ->
          Images.update_batch_tags(actor(admin_user_fixture()), %{
            tag_list: source.name,
            image_ids: [image.id]
          })
        end
      ])

    assert Enum.count(results, &(&1 == :ok)) == 1
    assert Enum.count(results, &match?({:ok, %{succeeded: 1, failed: 0}}, &1)) == 1

    tag_ids =
      image
      |> Repo.preload(:tags, force: true)
      |> Map.fetch!(:tags)
      |> Enum.map(& &1.id)

    assert target.id in tag_ids
    refute source.id in tag_ids
    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == 1
  end

  test "concurrent reindex and tagging preserve the image counter" do
    patch(Search, :reindex, :ok)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      base_tag_names = ["safe", "filler", "initial"]

      base_tag_ids =
        from(tag in Tag, where: tag.name in ^base_tag_names, select: tag.id)
        |> Repo.all()

      tag = tag_fixture(name: unique_tag_name())
      image = image_fixture(tags: "safe, filler, #{tag.name}")
      other_image = image_fixture(tags: "safe, filler, initial")
      admin = admin_user_fixture()

      tag
      |> Ecto.Changeset.change(images_count: 99)
      |> Repo.update!()

      try do
        results =
          concurrently([
            fn -> Tags.perform_reindex_images(tag.id) end,
            fn ->
              Images.update_image_tags(
                actor(admin),
                other_image.id,
                %{
                  "old_tag_input" => "safe, filler, initial",
                  "tag_input" => "safe, filler, initial, #{tag.name}"
                }
              )
            end
          ])

        assert Enum.any?(results, &(&1 == :ok))
        assert Enum.any?(results, &match?({:ok, %{}}, &1))
        assert Repo.reload!(tag).images_count == 2
      after
        Repo.delete!(image)
        Repo.delete!(other_image)
        Repo.delete!(tag)

        Repo.delete_all(
          from tag in Tag,
            where: tag.name in ^base_tag_names and tag.id not in ^base_tag_ids
        )

        Repo.delete!(admin)
      end
    end)
  end
end
