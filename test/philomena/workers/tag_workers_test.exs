defmodule Philomena.TagWorkersTest do
  use Philomena.DataCase, async: false
  use Patch

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.ArtistLinksFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.TagAliasWorker
  alias Philomena.TagDeleteWorker
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges.TagChangeTag
  alias Philomena.Tags.Tag
  alias Philomena.Tags
  alias PhilomenaQuery.Search

  defp tag_ids(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.id)
  end

  defp enqueued_args(worker) do
    for {:enqueue, [Exq, "indexing", ^worker, args]} <- history(Exq), do: args
  end

  test "the alias worker moves image taggings to the target tag" do
    source = tag_fixture(name: "worker alias source")
    target = tag_fixture(name: "worker alias target")
    image = image_fixture(tags: "safe, #{source.name}")

    source
    |> Ecto.Changeset.change(aliased_tag_id: target.id)
    |> Repo.update!()

    assert :ok = TagAliasWorker.perform(source.id, target.id)

    ids = tag_ids(image)
    assert target.id in ids
    refute source.id in ids
    assert Repo.reload!(source).aliased_tag_id == target.id
  end

  test "the alias worker moves visible image counts from source to target" do
    source = tag_fixture(name: "worker visible count source")
    target = tag_fixture(name: "worker visible count target")
    _image = image_fixture(tags: source.name)

    source = source |> Ecto.Changeset.change(images_count: 1) |> Repo.update!()
    target = target |> Ecto.Changeset.change(images_count: 0) |> Repo.update!()

    source
    |> Ecto.Changeset.change(aliased_tag_id: target.id)
    |> Repo.update!()

    assert :ok = TagAliasWorker.perform(source.id, target.id)

    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == 1
  end

  test "the alias worker reindexes the target and both tags when the source has no images" do
    source = tag_fixture(name: "worker empty alias source")
    target = tag_fixture(name: "worker empty alias target")

    source
    |> Ecto.Changeset.change(aliased_tag_id: target.id)
    |> Repo.update!()

    spy(Exq)

    assert :ok = TagAliasWorker.perform(source.id, target.id)

    assert enqueued_args(Philomena.TagReindexWorker) == [[target.id]]
    assert enqueued_args(Philomena.IndexWorker) == [["Tags", "id", [source.id, target.id]]]
  end

  test "the alias worker does not count hidden images when moving taggings" do
    source = tag_fixture(name: "worker hidden count source")
    target = tag_fixture(name: "worker hidden count target")
    _image = image_fixture(tags: source.name, hidden_from_users: true)

    source = source |> Ecto.Changeset.change(images_count: 0) |> Repo.update!()
    target = target |> Ecto.Changeset.change(images_count: 0) |> Repo.update!()

    source
    |> Ecto.Changeset.change(aliased_tag_id: target.id)
    |> Repo.update!()

    assert :ok = TagAliasWorker.perform(source.id, target.id)

    assert Repo.reload!(source).images_count == 0
    assert Repo.reload!(target).images_count == 0
  end

  test "aliasing deletes conflicting artist links before the worker runs" do
    admin = admin_user_fixture()
    user = confirmed_user_fixture()
    source = tag_fixture(name: "artist:worker alias source")
    target = tag_fixture(name: "artist:worker alias target")
    uri = "https://example.com/artist"

    source_link = artist_link_fixture(user, source, %{"uri" => uri})
    target_link = artist_link_fixture(user, target, %{"uri" => uri})

    assert {:ok, _tag} =
             Tags.update_tag_alias(
               actor(admin),
               source.slug,
               %{"target_tag" => target.name}
             )

    refute Repo.get(ArtistLink, source_link.id)
    assert Repo.get!(ArtistLink, target_link.id).tag_id == target.id
    assert Repo.reload!(source).aliased_tag_id == target.id
  end

  test "the delete worker removes the tag and its image taggings" do
    patch(Search, :delete_document, :ok)
    patch(Search, :reindex, :ok)

    tag = tag_fixture(name: "worker delete tag")
    image = image_fixture(tags: "safe, #{tag.name}")

    assert :ok = TagDeleteWorker.perform(tag.id)

    assert Repo.get(Tag, tag.id) == nil
    refute tag.id in tag_ids(image)
  end

  test "the delete worker removes the tag from history and drops emptied tag changes" do
    patch(Search, :delete_document, :ok)

    tag = tag_fixture(name: "worker delete history tag")
    other_tag = tag_fixture(name: "worker kept history tag")
    image = image_fixture()
    attribution = actor()

    insert_tag_change! = fn tags ->
      tag_change =
        Repo.insert!(%TagChange{
          image_id: image.id,
          ip: attribution.ip,
          fingerprint: attribution.fingerprint
        })

      for tag <- tags do
        Repo.insert!(%TagChangeTag{tag_change_id: tag_change.id, tag_id: tag.id, added: true})
      end

      tag_change
    end

    emptied = insert_tag_change!.([tag])
    retained = insert_tag_change!.([tag, other_tag])
    unrelated = insert_tag_change!.([])

    assert :ok = TagDeleteWorker.perform(tag.id)

    refute Repo.get(TagChange, emptied.id)
    emptied_id = emptied.id
    retained_id = retained.id
    unrelated_id = unrelated.id
    assert_called(Search.delete_document(^emptied_id, TagChange))
    refute_called(Search.delete_document(^retained_id, TagChange))
    refute_called(Search.delete_document(^unrelated_id, TagChange))
    assert Repo.get(TagChange, retained.id)
    assert Repo.get(TagChange, unrelated.id)
    refute Repo.get_by(TagChangeTag, tag_id: tag.id)
    assert Repo.get_by(TagChangeTag, tag_change_id: retained.id, tag_id: other_tag.id)
  end
end
