defmodule Philomena.TagChangesTest do
  @moduledoc """
  Context-level tests for the actor-first `Philomena.TagChanges` API:
  `delete_tag_change/2`, `revert_tag_changes/2`, and `full_revert/2`.

  These pin the authorization matrix (anonymous/user/moderator/admin), the
  two global error shapes, and the moderation log entries - type strings,
  bodies, and subject paths byte-for-byte - that each function writes on
  success. The corresponding controller characterization tests pin the HTTP
  behavior on top of these results.
  """

  use Philomena.DataCase, async: false
  use Patch

  # delete_tag_change/2 removes the record's search document, so this module
  # follows the OpenSearch test rules (async: false, index cycled in setup).
  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.TagsFixtures
  import Philomena.TagChangesFixtures

  import Ecto.Query

  alias Philomena.Images
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Repo
  alias Philomena.TagChanges
  alias Philomena.TagChanges.Query
  alias Philomena.TagChanges.QueryForm
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges.TagChangePage
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  @pagination %{page_number: 1, page_size: 25}

  setup do
    Search.clear_index!(TagChange)
    # Valkey rate-limit counters are not rolled back by the SQL sandbox; reset
    # the tag-change limit so accumulated counts don't trip check_limits.
    reset_tag_change_limits()
    :ok
  end

  # Arranges an image whose tags went from "safe" to three tags, returning the
  # image plus the single TagChange row that recorded the two adds.
  defp tag_change!(user) do
    image = image_fixture()

    # These tests arrange history rather than exercise the write rate limits.
    arrangement_actor =
      case user do
        nil ->
          actor(nil, ip: random_ip())

        user ->
          actor(%{user | bypass_rate_limits: true})
      end

    {:ok, result} =
      Images.update_image_tags(
        arrangement_actor,
        image.id,
        %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      )

    assert result.image.id == image.id
    {image, Repo.one!(from tc in TagChange, where: tc.image_id == ^image.id)}
  end

  defp image_tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
  end

  defp only_moderation_log! do
    Repo.one!(ModerationLog)
  end

  defp reindex_tag_changes! do
    SearchHelpers.reindex_all!(TagChange)
  end

  # Applies a tag edit through the real tag-input path, creating any new tag
  # names, and returns the TagChange row it recorded.
  defp update_tags!(image, user, old_tag_input, tag_input) do
    {:ok, _result} =
      Images.update_image_tags(actor(%{user | bypass_rate_limits: true}), image.id, %{
        "old_tag_input" => old_tag_input,
        "tag_input" => tag_input
      })

    Repo.one!(
      from tc in TagChange,
        where: tc.image_id == ^image.id,
        order_by: [desc: :id],
        limit: 1
    )
  end

  defp entry_ids({:ok, %TagChangePage{tag_changes: page}, _changeset}) do
    page.entries
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  describe "actor-scoped history reads" do
    test "the global listing returns a typed page and normalized query form" do
      {_image, tag_change} = tag_change!(confirmed_user_fixture())
      reindex_tag_changes!()

      assert {:ok,
              %TagChangePage{
                target: nil,
                tag_changes: page,
                added_query: "added_tag_count.gt:0",
                removed_query: "removed_tag_count.gt:0"
              }, %Ecto.Changeset{data: %QueryForm{sf: "tag_count", sd: "asc"}}} =
               TagChanges.list_tag_changes(
                 actor(),
                 %{"sf" => "tag_count", "sd" => "asc"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [tag_change.id]
    end

    test "invalid query and sort input return rejected changesets" do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               TagChanges.list_tag_changes(actor(), %{"sf" => "unknown"}, @pagination)

      assert "is invalid" in errors_on(changeset).sf

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               TagChanges.list_tag_changes(actor(), %{"tcq" => "("}, @pagination)

      assert errors_on(changeset).tcq != []
    end

    test "resource APIs resolve image, tag, and user targets independently" do
      user = confirmed_user_fixture()
      {image, tag_change} = tag_change!(user)
      tag = Repo.get_by!(Tag, name: "added test tag")
      reindex_tag_changes!()

      assert {:ok, %TagChangePage{target: loaded_image, tag_changes: page}, _} =
               TagChanges.list_image_tag_changes(actor(), image.id, %{}, @pagination)

      assert loaded_image.id == image.id
      assert Enum.map(page.entries, & &1.id) == [tag_change.id]

      assert {:ok, %TagChangePage{target: loaded_tag, tag_changes: page}, _} =
               TagChanges.list_tag_tag_changes(actor(), tag.slug, %{}, @pagination)

      assert loaded_tag.id == tag.id
      assert Enum.map(page.entries, & &1.id) == [tag_change.id]

      assert {:ok, %TagChangePage{target: loaded_user, tag_changes: page}, _} =
               TagChanges.list_user_tag_changes(actor(), user.slug, %{}, @pagination)

      assert loaded_user.id == user.id
      assert Enum.map(page.entries, & &1.id) == [tag_change.id]
    end

    test "the tag resource resolves aliases and includes their pre-alias history" do
      {_image, tag_change} = tag_change!(confirmed_user_fixture())
      canonical = Repo.get_by!(Tag, name: "added test tag")
      image = image_fixture()

      {:ok, _result} =
        Images.update_image_tags(actor(nil, ip: random_ip()), image.id, %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, former added test tag, other former tag"
        })

      alias_change = Repo.get_by!(TagChange, image_id: image.id)

      alias_tag =
        Tag
        |> Repo.get_by!(name: "former added test tag")
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      reindex_tag_changes!()

      for slug <- [alias_tag.slug, canonical.slug] do
        assert {:ok, %TagChangePage{target: loaded_tag, tag_changes: page}, _changeset} =
                 TagChanges.list_tag_tag_changes(actor(), slug, %{}, @pagination)

        assert loaded_tag.id == canonical.id
        assert Enum.sort(Enum.map(page.entries, & &1.id)) == [tag_change.id, alias_change.id]
      end
    end

    test "resource filters compose with tcq rather than replacing it" do
      {image, tag_change} = tag_change!(confirmed_user_fixture())
      other = image_fixture()
      reindex_tag_changes!()

      assert {:ok, %TagChangePage{tag_changes: page}, _} =
               TagChanges.list_image_tag_changes(
                 actor(),
                 image.id,
                 %{"tcq" => "image_id:#{other.id}"},
                 @pagination
               )

      assert page.entries == []
      assert page.total_entries == 0

      assert {:ok, %TagChangePage{tag_changes: page}, _} =
               TagChanges.list_image_tag_changes(
                 actor(),
                 image.id,
                 %{"tcq" => "id:#{tag_change.id}"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [tag_change.id]
    end

    test "missing resource targets are not found before search" do
      assert TagChanges.list_image_tag_changes(actor(), "not-an-id", %{}, @pagination) ==
               {:error, :not_found}

      assert TagChanges.list_image_tag_changes(actor(), "2147483647", %{}, @pagination) ==
               {:error, :not_found}

      assert TagChanges.list_tag_tag_changes(actor(), "no-such-tag", %{}, @pagination) ==
               {:error, :not_found}

      assert TagChanges.list_user_tag_changes(actor(), "no-such-user", %{}, @pagination) ==
               {:error, :not_found}
    end

    test "hidden image changes ignore image visibility in global listings but not image listings" do
      {image, tag_change} = tag_change!(confirmed_user_fixture())

      image
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      reindex_tag_changes!()

      assert {:ok, %TagChangePage{tag_changes: global_page}, _} =
               TagChanges.list_tag_changes(actor(), %{}, @pagination)

      assert Enum.map(global_page.entries, & &1.id) == [tag_change.id]

      assert TagChanges.list_image_tag_changes(actor(), image.id, %{}, @pagination) ==
               {:error, :unauthorized}

      moderator = actor(moderator_user_fixture())

      assert {:ok, %TagChangePage{tag_changes: global_page}, _} =
               TagChanges.list_tag_changes(moderator, %{}, @pagination)

      assert Enum.map(global_page.entries, & &1.id) == [tag_change.id]

      assert {:ok, %TagChangePage{tag_changes: image_page}, _} =
               TagChanges.list_image_tag_changes(moderator, image.id, %{}, @pagination)

      assert Enum.map(image_page.entries, & &1.id) == [tag_change.id]
    end

    test "IP and fingerprint locators validate before their sensitive gate" do
      moderator = actor(moderator_user_fixture())
      {_image, tag_change} = tag_change!(confirmed_user_fixture())
      reindex_tag_changes!()

      assert TagChanges.list_ip_tag_changes(actor(), "bad-ip", %{}, @pagination) ==
               {:error, :not_found}

      assert TagChanges.list_ip_tag_changes(actor(), "203.0.113.1", %{}, @pagination) ==
               {:error, :unauthorized}

      assert {:ok, %TagChangePage{tag_changes: ip_page}, _} =
               TagChanges.list_ip_tag_changes(moderator, "203.0.113.1", %{}, @pagination)

      assert Enum.map(ip_page.entries, & &1.id) == [tag_change.id]

      assert TagChanges.list_fingerprint_tag_changes(actor(), "invalid", %{}, @pagination) ==
               {:error, :not_found}

      assert TagChanges.list_fingerprint_tag_changes(
               actor(),
               "d015c342859dde3",
               %{},
               @pagination
             ) == {:error, :unauthorized}

      assert {:ok,
              %TagChangePage{
                target: "d015c342859dde3",
                tag_changes: fingerprint_page
              }, _} =
               TagChanges.list_fingerprint_tag_changes(
                 moderator,
                 " D015C342859DDE3 ",
                 %{},
                 @pagination
               )

      assert Enum.map(fingerprint_page.entries, & &1.id) == [tag_change.id]
    end

    test "sensitive tcq fields are authorized without direct role matching" do
      {_image, tag_change} = tag_change!(confirmed_user_fixture())
      reindex_tag_changes!()

      assert {:ok, %TagChangePage{tag_changes: ordinary_page},
              %Ecto.Changeset{
                data: %QueryForm{compiled_query: %{term: %{"tag" => "ip:203.0.113.1"}}}
              }} =
               TagChanges.list_tag_changes(
                 actor(confirmed_user_fixture()),
                 %{"tcq" => "ip:203.0.113.1"},
                 @pagination
               )

      assert ordinary_page.entries == []

      assert {:ok, %TagChangePage{tag_changes: page},
              %Ecto.Changeset{
                data: %QueryForm{compiled_query: %{term: %{"ip" => "203.0.113.1"}}}
              }} =
               TagChanges.list_tag_changes(
                 actor(moderator_user_fixture()),
                 %{"tcq" => "ip:203.0.113.1"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [tag_change.id]
    end

    test "pagination totals and deterministic ordering match the visible result set" do
      user = confirmed_user_fixture()
      {_image, older} = tag_change!(user)
      {_image, middle} = tag_change!(user)
      {_image, newer} = tag_change!(user)
      reindex_tag_changes!()

      assert {:ok, %TagChangePage{tag_changes: page}, _} =
               TagChanges.list_tag_changes(actor(), %{}, %{page_number: 1, page_size: 2})

      assert Enum.map(page.entries, & &1.id) == [newer.id, middle.id]
      assert page.total_entries == 3
      assert page.total_pages == 2
      refute older.id in Enum.map(page.entries, & &1.id)
    end
  end

  describe "added and removed shortcut queries" do
    test "listings other than a tag's narrow by added and removed tag counts" do
      user = confirmed_user_fixture()
      {image, _tag_change} = tag_change!(user)
      moderator = actor(moderator_user_fixture())

      results = [
        TagChanges.list_tag_changes(actor(), %{}, @pagination),
        TagChanges.list_image_tag_changes(actor(), image.id, %{}, @pagination),
        TagChanges.list_user_tag_changes(actor(), user.slug, %{}, @pagination),
        TagChanges.list_ip_tag_changes(moderator, "203.0.113.1", %{}, @pagination),
        TagChanges.list_fingerprint_tag_changes(moderator, "d015c342859dde3", %{}, @pagination)
      ]

      for result <- results do
        assert {:ok,
                %TagChangePage{
                  added_query: "added_tag_count.gt:0",
                  removed_query: "removed_tag_count.gt:0"
                }, %Ecto.Changeset{}} = result
      end
    end

    test "the count queries select the changes that added and that removed any tag" do
      user = confirmed_user_fixture()
      image = image_fixture(tags: "safe, base one, base two")
      tag = tag_fixture(name: unique_tag_name())
      swapped_in = unique_tag_name()

      adding = create_tag_change!(image, tag, user, true)
      removing = create_tag_change!(image, tag, user, false)

      swapping =
        update_tags!(image, user, "safe, base one, base two", "safe, base one, #{swapped_in}")

      reindex_tag_changes!()

      assert {:ok, %TagChangePage{added_query: added_query, removed_query: removed_query}, _} =
               result = TagChanges.list_image_tag_changes(actor(), image.id, %{}, @pagination)

      assert entry_ids(result) == Enum.sort([adding.id, removing.id, swapping.id])

      assert entry_ids(
               TagChanges.list_image_tag_changes(
                 actor(),
                 image.id,
                 %{"tcq" => added_query},
                 @pagination
               )
             ) == Enum.sort([adding.id, swapping.id])

      assert entry_ids(
               TagChanges.list_image_tag_changes(
                 actor(),
                 image.id,
                 %{"tcq" => removed_query},
                 @pagination
               )
             ) == Enum.sort([removing.id, swapping.id])
    end

    test "a tag listing narrows by additions and removals of its own tag" do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: unique_tag_name())

      adding =
        create_tag_change!(image_fixture(tags: "safe, base one, base two"), tag, user, true)

      removing =
        create_tag_change!(
          image_fixture(tags: "safe, base one, base two, #{tag.name}"),
          tag,
          user,
          false
        )

      reindex_tag_changes!()

      assert {:ok,
              %TagChangePage{
                target: %Tag{},
                added_query: added_query,
                removed_query: removed_query
              }, _} =
               result = TagChanges.list_tag_tag_changes(actor(), tag.slug, %{}, @pagination)

      assert added_query == "added_tag:#{tag.name}"
      assert removed_query == "removed_tag:#{tag.name}"
      assert entry_ids(result) == Enum.sort([adding.id, removing.id])

      assert entry_ids(
               TagChanges.list_tag_tag_changes(
                 actor(),
                 tag.slug,
                 %{"tcq" => added_query},
                 @pagination
               )
             ) == [adding.id]

      assert entry_ids(
               TagChanges.list_tag_tag_changes(
                 actor(),
                 tag.slug,
                 %{"tcq" => removed_query},
                 @pagination
               )
             ) == [removing.id]
    end

    test "a tag name the parser would reinterpret yields an escaped query for that tag only" do
      user = confirmed_user_fixture()
      n = System.unique_integer([:positive])
      name = "wild*card :) #{n}"
      # An unescaped `*` would make the tag's query a wildcard matching this name.
      decoy = "wildxcard :) #{n}"

      adding_image = image_fixture(tags: "safe, base one, base two")
      decoy_image = image_fixture(tags: "safe, base one, base two")

      adding =
        update_tags!(
          adding_image,
          user,
          "safe, base one, base two",
          "safe, base one, base two, #{name}"
        )

      decoy_change =
        update_tags!(
          decoy_image,
          user,
          "safe, base one, base two",
          "safe, base one, base two, #{decoy}"
        )

      tag = Repo.get_by!(Tag, name: name)

      removing =
        create_tag_change!(
          image_fixture(tags: "safe, base one, base two, #{name}"),
          tag,
          user,
          false
        )

      reindex_tag_changes!()

      assert {:ok, %TagChangePage{added_query: added_query, removed_query: removed_query}, _} =
               TagChanges.list_tag_tag_changes(actor(), tag.slug, %{}, @pagination)

      assert added_query == ~s["added_tag:wild\\\\*card :) #{n}"]
      assert removed_query == ~s["removed_tag:wild\\\\*card :) #{n}"]
      assert Query.compile(added_query) == {:ok, %{term: %{"added_tag" => name}}}
      assert Query.compile(removed_query) == {:ok, %{term: %{"removed_tag" => name}}}

      assert entry_ids(
               TagChanges.list_tag_tag_changes(
                 actor(),
                 tag.slug,
                 %{"tcq" => added_query},
                 @pagination
               )
             ) == [adding.id]

      assert entry_ids(
               TagChanges.list_tag_tag_changes(
                 actor(),
                 tag.slug,
                 %{"tcq" => removed_query},
                 @pagination
               )
             ) == [removing.id]

      # The query alone, outside the tag's resource filter, excludes the decoy
      # that the unescaped form matches.
      assert entry_ids(TagChanges.list_tag_changes(actor(), %{"tcq" => added_query}, @pagination)) ==
               [adding.id]

      assert entry_ids(
               TagChanges.list_tag_changes(
                 actor(),
                 %{"tcq" => ~s["added_tag:wild*card :) #{n}"]},
                 @pagination
               )
             ) == Enum.sort([adding.id, decoy_change.id])
    end
  end

  describe "delete_tag_change/2" do
    test "denies an anonymous actor" do
      {_image, tc} = tag_change!(confirmed_user_fixture())

      assert TagChanges.delete_tag_change(actor(), "#{tc.id}") == {:error, :unauthorized}
      assert Repo.get(TagChange, tc.id)
    end

    test "denies a regular user" do
      {_image, tc} = tag_change!(confirmed_user_fixture())

      assert TagChanges.delete_tag_change(actor(confirmed_user_fixture()), "#{tc.id}") ==
               {:error, :unauthorized}

      assert Repo.get(TagChange, tc.id)
    end

    test "a moderator deletes the change and a moderation log is written" do
      author = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      {image, tc} = tag_change!(author)
      reindex_tag_changes!()

      assert {:ok, %TagChange{}} = TagChanges.delete_tag_change(actor(moderator), "#{tc.id}")
      refute Repo.get(TagChange, tc.id)

      Search.refresh_index!(TagChange)

      assert {:ok, %TagChangePage{tag_changes: page}, _changeset} =
               TagChanges.list_tag_changes(actor(moderator), %{}, @pagination)

      assert page.entries == []

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "TagChange:delete"
      assert log.subject_path == "/images/#{image.id}"

      assert log.body ==
               "Deleted tag change by #{author.name} containing 2 tags on image #{image.id} from history"
    end

    test "an admin may also delete" do
      {_image, tc} = tag_change!(confirmed_user_fixture())

      assert {:ok, %TagChange{}} =
               TagChanges.delete_tag_change(actor(admin_user_fixture()), tc.id)
    end

    test "a moderator deletes an anonymous change without crashing" do
      moderator = moderator_user_fixture()
      {image, tag_change} = tag_change!(nil)

      assert {:ok, %TagChange{}} =
               TagChanges.delete_tag_change(actor(moderator), tag_change.id)

      refute Repo.get(TagChange, tag_change.id)

      log = only_moderation_log!()
      assert log.subject_path == Paths.image_path(image)
      assert log.body =~ "Deleted tag change by an anonymous user"
    end

    test "a well-formed id naming no row is not found" do
      assert TagChanges.delete_tag_change(actor(moderator_user_fixture()), "123456789") ==
               {:error, :not_found}
    end

    test "an id that cannot name a row is not found" do
      moderator = moderator_user_fixture()

      assert TagChanges.delete_tag_change(actor(moderator), "not-an-integer") ==
               {:error, :not_found}

      assert TagChanges.delete_tag_change(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "create_tag_change_revert/2" do
    test "denies an anonymous actor" do
      assert TagChanges.create_tag_change_revert(actor(), ["1"]) == {:error, :unauthorized}
    end

    test "denies a regular user before looking at the ids" do
      # Authorization comes first, as it did when it was a plug: a bad ids
      # shape from an unprivileged user is still unauthorized.
      user_actor = actor(confirmed_user_fixture())

      assert TagChanges.create_tag_change_revert(user_actor, ["1"]) == {:error, :unauthorized}
      assert TagChanges.create_tag_change_revert(user_actor, "42") == {:error, :unauthorized}
    end

    test "a moderator reverts the listed changes and a moderation log is written" do
      moderator = moderator_user_fixture()
      {image, tc} = tag_change!(confirmed_user_fixture())

      assert "added test tag" in image_tag_names(image)

      assert {:ok, [%TagChange{}]} =
               TagChanges.create_tag_change_revert(actor(moderator), %{"ids" => ["#{tc.id}"]})

      # Reverting the change removes the two tags it had added.
      names = image_tag_names(image)
      refute "added test tag" in names
      refute "other added tag" in names
      assert "safe" in names

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "TagChange.Revert:create"
      # Slug encoding (e.g. `@` → `%40`) is pinned in the Paths tests.
      assert log.subject_path == Paths.profile_path(moderator)
      assert log.body == "Reverted 1 tag changes"
    end

    test "an empty list is a successful reversion of zero changes" do
      assert {:ok, []} =
               TagChanges.create_tag_change_revert(actor(moderator_user_fixture()), %{ids: []})

      assert only_moderation_log!().body == "Reverted 0 tag changes"
    end

    test "reverting an already-reverted change is safe" do
      moderator = actor(moderator_user_fixture())
      {image, tag_change} = tag_change!(confirmed_user_fixture())

      assert {:ok, [%TagChange{}]} =
               TagChanges.create_tag_change_revert(moderator, %{ids: [tag_change.id]})

      assert {:ok, [%TagChange{}]} =
               TagChanges.create_tag_change_revert(moderator, %{ids: [tag_change.id]})

      names = image_tag_names(image)
      refute "added test tag" in names
      refute "other added tag" in names
      assert "safe" in names
    end

    test "a non-list ids value from a moderator is invalid" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               TagChanges.create_tag_change_revert(actor(moderator_user_fixture()), %{
                 "ids" => "42"
               })

      assert changeset.errors[:ids]

      assert Repo.aggregate(ModerationLog, :count) == 0
    end

    test "a list containing a malformed id is invalid before reversion" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               TagChanges.create_tag_change_revert(actor(moderator_user_fixture()), %{
                 "ids" => ["not-an-id"]
               })

      assert changeset.errors[:ids]

      assert Repo.aggregate(ModerationLog, :count) == 0
    end

    test "reversion does not duplicate a source tagging" do
      user = admin_user_fixture()
      source = tag_fixture(name: unique_tag_name())
      target = tag_fixture(name: unique_tag_name())
      image = image_fixture(tags: "safe, base one, base two, #{source.name}")
      removed_change = create_tag_change!(image, source, user, false)
      _later_add = create_tag_change!(image, source, user, true)

      source
      |> Ecto.Changeset.change(aliased_tag_id: target.id, images_count: 1)
      |> Repo.update!()

      initial_change_count = Repo.aggregate(TagChange, :count)

      assert {:ok, [_]} =
               TagChanges.create_tag_change_revert(actor(user), %{ids: [removed_change.id]})

      assert Repo.aggregate(TagChange, :count) == initial_change_count
    end
  end

  describe "full_revert_*_tag_changes/2" do
    test "denies an anonymous actor" do
      assert TagChanges.create_user_tag_change_revert(actor(), "user") == {:error, :unauthorized}

      assert TagChanges.create_ip_tag_change_revert(actor(), "203.0.113.1") ==
               {:error, :unauthorized}

      assert TagChanges.create_fingerprint_tag_change_revert(actor(), "c1774") ==
               {:error, :unauthorized}
    end

    test "denies a regular user before looking at the target" do
      user_actor = actor(confirmed_user_fixture())

      assert TagChanges.create_user_tag_change_revert(user_actor, "user") ==
               {:error, :unauthorized}

      assert TagChanges.create_ip_tag_change_revert(user_actor, "203.0.113.1") ==
               {:error, :unauthorized}

      assert TagChanges.create_fingerprint_tag_change_revert(user_actor, "c1774") ==
               {:error, :unauthorized}
    end

    test "a moderator enqueues a reversion for a user and the log names them" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert {:ok, result} =
               TagChanges.create_user_tag_change_revert(actor(moderator), target.slug)

      assert result.id == target.id

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "TagChange.FullRevert:create"
      assert log.subject_path == Paths.profile_path(target)
      assert log.body == "Reverted all tag changes for user #{target.name}"
    end

    test "a missing user profile is not found" do
      assert TagChanges.create_user_tag_change_revert(
               actor(moderator_user_fixture()),
               "missing"
             ) == {:error, :not_found}
    end

    test "a moderator enqueues a reversion for an ip" do
      assert {:ok, "203.0.113.9"} =
               TagChanges.create_ip_tag_change_revert(
                 actor(moderator_user_fixture()),
                 "203.0.113.9"
               )

      log = only_moderation_log!()
      assert log.type == "TagChange.FullRevert:create"
      assert log.subject_path == "/ip_profiles/203.0.113.9"
      assert log.body == "Reverted all tag changes for ip 203.0.113.9"
    end

    test "a moderator enqueues a reversion for a fingerprint" do
      assert {:ok, "c1774"} =
               TagChanges.create_fingerprint_tag_change_revert(
                 actor(moderator_user_fixture()),
                 "c1774"
               )

      log = only_moderation_log!()
      assert log.subject_path == "/fingerprint_profiles/c1774"
      assert log.body == "Reverted all tag changes for fingerprint c1774"
    end

    test "invalid targets are not found" do
      assert TagChanges.create_user_tag_change_revert(
               actor(moderator_user_fixture()),
               "not-a-user"
             ) ==
               {:error, :not_found}

      assert TagChanges.create_ip_tag_change_revert(actor(moderator_user_fixture()), "not-an-ip") ==
               {:error, :not_found}

      assert TagChanges.create_fingerprint_tag_change_revert(
               actor(moderator_user_fixture()),
               "invalid"
             ) == {:error, :not_found}

      assert Repo.aggregate(ModerationLog, :count) == 0
    end
  end

  describe "wipe_user_attribution!/3" do
    test "replaces the user's IP and fingerprint and queues the rows for reindexing" do
      user = confirmed_user_fixture()
      {_image, tag_change} = tag_change!(user)
      {_image, other_change} = tag_change!(confirmed_user_fixture())
      wipe_ip = %Postgrex.INET{address: {127, 0, 1, 1}, netmask: 32}
      spy(Exq)

      assert TagChanges.wipe_user_attribution!(user.id, wipe_ip, "ffff") == :ok

      assert %TagChange{ip: ^wipe_ip, fingerprint: "ffff"} = Repo.reload!(tag_change)
      refute Repo.reload!(other_change).fingerprint == "ffff"

      reindex = [Exq, "indexing", Philomena.IndexWorker, ["TagChanges", "id", [tag_change.id]]]
      assert {:enqueue, reindex} in history(Exq)
    end
  end
end
