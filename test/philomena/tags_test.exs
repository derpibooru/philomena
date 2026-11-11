defmodule Philomena.TagsTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.Tags` functions and
  their typed page, detail, and search-form results.

  These pin the per-role authorization matrices on the edit/alias/delete/image
  paths, load-before-authorize not-found behavior, the byte-exact moderation
  logs the write paths emit, and the two search-backed loaders.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Tags
  alias Philomena.Tags.QueryForm
  alias Philomena.Tags.Implication
  alias Philomena.Tags.Tag
  alias Philomena.Tags.TagDetail
  alias Philomena.Tags.TagPage
  alias Philomena.Images.Image
  alias Philomena.Images.Search.Scope
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Repo
  alias Philomena.Multi
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  @pagination %{page_number: 1, page_size: 25}

  @limit Tag.name_length_limit()

  setup do
    Search.clear_index!(Tag)
    Search.clear_index!(Image)
    :ok
  end

  # The compiled filter body for a viewer with no active filter: it excludes
  # nothing.
  defp default_filter do
    %{
      bool: %{
        should: [
          %{terms: %{tag_ids: []}},
          %{bool: %{should: [%{match_none: %{}}, %{match_none: %{}}]}}
        ]
      }
    }
  end

  defp scope(_user) do
    Scope.new(default_filter(), @pagination)
  end

  defp only_moderation_log!, do: Repo.one!(ModerationLog)

  defp moderation_log_count, do: Repo.aggregate(ModerationLog, :count)

  describe "list_tags_by_ids/1" do
    test "loads matching tags and omits unknown IDs" do
      first = tag_fixture(name: "bulk first")
      second = tag_fixture(name: "bulk second")

      loaded = Tags.list_tags_by_ids([first.id, 2_147_483_647, second.id])

      assert Enum.sort(Enum.map(loaded, & &1.id)) == Enum.sort([first.id, second.id])
    end
  end

  describe "autocomplete_tags/2" do
    test "prefix-matches tags and uses current PostgreSQL counts for ranking" do
      lower =
        tag_fixture(name: "autocomplete lower")
        |> Ecto.Changeset.change(images_count: 4)
        |> Repo.update!()

      higher =
        tag_fixture(name: "autocomplete higher")
        |> Ecto.Changeset.change(images_count: 12)
        |> Repo.update!()

      zero = tag_fixture(name: "autocomplete zero")
      SearchHelpers.reindex_all!(Tag)

      assert [first, second] = Tags.autocomplete_tags("autocomplete", 2)
      assert {first.canonical, first.images} == {higher.name, 12}
      assert {second.canonical, second.images} == {lower.name, 4}
      refute Enum.any?([first, second], &(&1.canonical == zero.name))
    end

    test "identifies aliases and reports their canonical tag data" do
      canonical =
        tag_fixture(name: "suggestion target")
        |> Ecto.Changeset.change(images_count: 8)
        |> Repo.update!()

      alias_tag =
        tag_fixture(name: "suggestion alias")
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      SearchHelpers.reindex_all!(Tag)

      assert [suggestion] = Tags.autocomplete_tags("suggestion alias", 1)
      assert suggestion.alias == alias_tag.name
      assert suggestion.canonical == canonical.name
      assert suggestion.images == 8
    end
  end

  describe "quick_tag_table/0" do
    test "computes quick-tag data and caches it until refreshed" do
      on_exit(fn -> :persistent_term.erase({Philomena.Tags.QuickTagTable, :table}) end)

      safe = tag_fixture(name: "safe")
      SearchHelpers.reindex_all!(Tag)

      table = Tags.refresh_quick_tag_table()
      assert table.tags["safe"].id == safe.id
      assert Ecto.assoc_loaded?(table.tags["safe"].implied_tags)

      safe
      |> Ecto.Changeset.change(short_description: "changed after caching")
      |> Repo.update!()

      assert Tags.quick_tag_table().tags["safe"].short_description == ""

      assert Tags.refresh_quick_tag_table().tags["safe"].short_description ==
               "changed after caching"
    end
  end

  describe "query_tags/3" do
    test "finds an indexed tag by a wildcard query, carrying the default preloads" do
      tag = tag_fixture()
      SearchHelpers.reindex_all!(Tag)

      assert {:ok, tags, %Ecto.Changeset{data: %QueryForm{query: "*"}}} =
               Tags.query_tags(actor(), %{"query" => "*"}, @pagination)

      assert %Tag{} = found = Enum.find(tags, &(&1.id == tag.id))
      assert Ecto.assoc_loaded?(found.aliases)
      assert Ecto.assoc_loaded?(found.dnp_entries)
    end

    test "a missing query compiles to match-none, returning an empty page" do
      tag_fixture()
      SearchHelpers.reindex_all!(Tag)

      assert {:ok, tags, %Ecto.Changeset{data: %QueryForm{query: nil}}} =
               Tags.query_tags(actor(), %{"query" => nil}, @pagination)

      assert Enum.empty?(tags)
    end

    test "the caller owns pagination and results always carry representation preloads" do
      tag = tag_fixture()
      SearchHelpers.reindex_all!(Tag)

      pagination = %{@pagination | page_size: 250}

      assert {:ok, tags, %Ecto.Changeset{}} =
               Tags.query_tags(actor(), %{"query" => "*"}, pagination)

      assert tags.page_size == 250
      assert %Tag{} = found = Enum.find(tags, &(&1.id == tag.id))
      assert Ecto.assoc_loaded?(found.aliases)
    end

    test "a malformed query returns the rejected query form" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Tags.query_tags(actor(), %{"query" => "("}, @pagination)

      assert %{query: [message]} = errors_on(changeset)
      assert is_binary(message)
    end
  end

  describe "show_tag_page/2" do
    test "assembles the page for a real tag, carrying its tagged image" do
      created_at = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
      image = image_fixture(tags: "safe", created_at: created_at)
      tag = Repo.get_by!(Tag, name: "safe")
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %TagPage{} = page} = Tags.show_tag_page(actor(), scope(nil), tag.slug)

      assert page.tag.id == tag.id
      assert image.id in Enum.map(page.images, & &1.id)
      assert is_list(page.interactions)
      # A tag whose name compiles back to itself is used verbatim.
      assert page.search_query == "safe"
    end

    test "an aliased tag reports the tag it is aliased into" do
      target = tag_fixture(name: "load page target")

      aliased =
        tag_fixture()
        |> Ecto.Changeset.change(aliased_tag_id: target.id)
        |> Repo.update!()

      assert {:aliased_to, %Tag{} = returned} =
               Tags.show_tag_page(actor(), scope(nil), aliased.slug)

      assert returned.id == aliased.id
      assert returned.aliased_tag.id == target.id
    end

    test "an unknown slug is not-found for every viewer" do
      assert Tags.show_tag_page(actor(), scope(nil), "nonexistent-tag") ==
               {:error, :not_found}

      user = confirmed_user_fixture()

      assert Tags.show_tag_page(actor(user), scope(user), "nonexistent-tag") ==
               {:error, :not_found}

      moderator = moderator_user_fixture()

      assert Tags.show_tag_page(actor(moderator), scope(moderator), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "show_tag/2 and load_canonical_tag/2" do
    test "the representation loader preserves an alias while the canonical loader resolves it" do
      target = tag_fixture(name: "canonical target")

      aliased =
        tag_fixture(name: "canonical alias")
        |> Ecto.Changeset.change(aliased_tag_id: target.id)
        |> Repo.update!()

      assert {:ok, %Tag{id: alias_id, aliased_tag: %Tag{id: target_id}}} =
               Tags.show_tag(actor(), aliased.slug)

      assert alias_id == aliased.id
      assert target_id == target.id

      assert {:ok, %Tag{id: canonical_id}} = Tags.load_canonical_tag(actor(), aliased.slug)
      assert canonical_id == target.id
    end

    test "missing and malformed locators are not found" do
      assert Tags.show_tag(actor(), "missing") == {:error, :not_found}
      assert Tags.show_tag(actor(), nil) == {:error, :not_found}
      assert Tags.load_canonical_tag(actor(), nil) == {:error, :not_found}
    end
  end

  describe "edit_tag/3" do
    test "a moderator loads the tag paired with its edit changeset" do
      tag = tag_fixture()

      assert {:ok, {%Tag{} = loaded, %Ecto.Changeset{} = changeset}} =
               Tags.edit_tag(actor(moderator_user_fixture()), tag.slug)

      assert loaded.id == tag.id
      assert changeset.data.id == tag.id
    end

    test "anonymous and regular users are unauthorized" do
      tag = tag_fixture()

      assert Tags.edit_tag(actor(), tag.slug) == {:error, :unauthorized}

      assert Tags.edit_tag(actor(confirmed_user_fixture()), tag.slug) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.edit_tag(actor(admin_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.edit_tag(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "update_tag/3" do
    test "a moderator updates the tag and writes a moderation log" do
      tag = tag_fixture()

      assert {:ok, %Tag{} = updated} =
               Tags.update_tag(actor(moderator_user_fixture()), tag.slug, %{
                 "category" => "rating"
               })

      assert updated.id == tag.id
      assert Repo.reload!(tag).category == "rating"

      log = only_moderation_log!()
      assert log.type == "Tag:update"
      assert log.subject_path == Paths.tag_path(tag)
      assert log.body == "Updated details on tag '#{tag.name}'"
    end

    test "a category outside the allowed list is a rejected changeset and writes no log" do
      tag = tag_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Tags.update_tag(actor(moderator_user_fixture()), tag.slug, %{"category" => "bogus"})

      refute changeset.valid?
      assert Repo.reload!(tag).category == tag.category
      assert moderation_log_count() == 0
    end

    test "updating to another allowed category succeeds and writes a log" do
      tag = tag_fixture()

      assert {:ok, %Tag{}} =
               Tags.update_tag(actor(moderator_user_fixture()), tag.slug, %{
                 "category" => "species"
               })

      assert Repo.reload!(tag).category == "species"
      assert only_moderation_log!().type == "Tag:update"
    end

    test "rejects aliased tags in the implied-tag list" do
      tag = tag_fixture(name: "implied list source")
      implied_tag = tag_fixture(name: "implied list alias")
      canonical_tag = tag_fixture(name: "implied list canonical")

      implied_tag
      |> Ecto.Changeset.change(aliased_tag_id: canonical_tag.id)
      |> Repo.update!()

      assert {:error, changeset} =
               Tags.update_tag(actor(moderator_user_fixture()), tag.slug, %{
                 "implied_tag_list" => implied_tag.name
               })

      assert %{implied_tag_list: ["contains aliased tags"]} = errors_on(changeset)
      refute Repo.exists?(from implication in Implication, where: implication.tag_id == ^tag.id)
      assert moderation_log_count() == 0
    end

    test "anonymous and regular users are unauthorized and change nothing" do
      tag = tag_fixture()

      assert Tags.update_tag(actor(), tag.slug, %{"category" => "rating"}) ==
               {:error, :unauthorized}

      assert Tags.update_tag(actor(confirmed_user_fixture()), tag.slug, %{"category" => "rating"}) ==
               {:error, :unauthorized}

      assert Repo.reload!(tag).category == tag.category
      assert moderation_log_count() == 0
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.update_tag(actor(admin_user_fixture()), "nonexistent-tag", %{
               "category" => "rating"
             }) ==
               {:error, :not_found}

      assert Tags.update_tag(actor(moderator_user_fixture()), "nonexistent-tag", %{
               "category" => "rating"
             }) == {:error, :not_found}
    end
  end

  describe "delete_tag/2" do
    test "an admin queues the deletion and writes a moderation log" do
      tag = tag_fixture()

      assert {:ok, %Tag{} = deleted} = Tags.delete_tag(actor(admin_user_fixture()), tag.slug)
      assert deleted.id == tag.id
      # Deletion is performed asynchronously by the worker; the row is still
      # present synchronously.
      assert Repo.get(Tag, tag.id)

      log = only_moderation_log!()
      assert log.type == "Tag:delete"
      assert log.subject_path == Paths.tag_path(tag)
      assert log.body == "Deleted tag '#{tag.name}'"
    end

    test "a plain moderator lacks :delete and is unauthorized" do
      tag = tag_fixture()

      assert Tags.delete_tag(actor(moderator_user_fixture()), tag.slug) == {:error, :unauthorized}
      assert Repo.get(Tag, tag.id)
      assert moderation_log_count() == 0
    end

    test "anonymous and regular users are unauthorized" do
      tag = tag_fixture()

      assert Tags.delete_tag(actor(), tag.slug) == {:error, :unauthorized}
      assert Tags.delete_tag(actor(confirmed_user_fixture()), tag.slug) == {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.delete_tag(actor(admin_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.delete_tag(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "edit_tag_alias/2" do
    test "an admin loads the tag paired with its edit changeset" do
      tag = tag_fixture()

      assert {:ok, {%Tag{} = loaded, %Ecto.Changeset{}}} =
               Tags.edit_tag_alias(actor(admin_user_fixture()), tag.slug)

      assert loaded.id == tag.id
    end

    test "a plain moderator lacks :alias and is unauthorized" do
      tag = tag_fixture()

      assert Tags.edit_tag_alias(actor(moderator_user_fixture()), tag.slug) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.edit_tag_alias(actor(admin_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.edit_tag_alias(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "update_tag_alias/3" do
    test "an admin aliases the tag into the target and writes a moderation log" do
      target = tag_fixture(name: "alias context target")
      tag = tag_fixture()

      assert {:ok, %Tag{} = aliased} =
               Tags.update_tag_alias(actor(admin_user_fixture()), tag.slug, %{
                 "target_tag" => target.name
               })

      assert aliased.id == tag.id
      assert Repo.reload!(tag).aliased_tag_id == target.id

      log = only_moderation_log!()
      assert log.type == "Tag.Alias:update"
      assert log.subject_path == Paths.tag_path(tag)
      assert log.body == "Aliased tag '#{tag.name}' into '#{target.name}'"
    end

    test "aliasing into an unknown target is a changeset error and writes no log" do
      tag = tag_fixture()

      assert {:error, changeset} =
               Tags.update_tag_alias(actor(admin_user_fixture()), tag.slug, %{
                 "target_tag" => "no such tag"
               })

      assert %{aliased_tag: ["does not exist"]} = errors_on(changeset)

      assert Repo.reload!(tag).aliased_tag_id == nil
      assert moderation_log_count() == 0
    end

    test "accepts atom-keyed form attributes" do
      target = tag_fixture(name: "atom alias target")
      tag = tag_fixture(name: "atom alias source")

      assert {:ok, %Tag{aliased_tag_id: target_id}} =
               Tags.update_tag_alias(actor(admin_user_fixture()), tag.slug, %{
                 target_tag: target.name
               })

      assert target_id == target.id
    end

    test "rejects self-aliases and tags that already have incoming aliases" do
      admin = actor(admin_user_fixture())
      tag = tag_fixture(name: "alias conflict source")

      assert {:error, self_changeset} =
               Tags.update_tag_alias(admin, tag.slug, %{"target_tag" => tag.name})

      assert %{aliased_tag: [_message]} = errors_on(self_changeset)

      _incoming =
        tag_fixture(name: "incoming alias")
        |> Ecto.Changeset.change(aliased_tag_id: tag.id)
        |> Repo.update!()

      target = tag_fixture(name: "alias conflict target")

      assert {:error, incoming_changeset} =
               Tags.update_tag_alias(admin, tag.slug, %{"target_tag" => target.name})

      assert %{tag: [_message]} = errors_on(incoming_changeset)
    end

    test "rejects aliasing a tag that is implied by another tag" do
      admin = actor(admin_user_fixture())
      parent = tag_fixture(name: "implied parent")
      source = tag_fixture(name: "implied source")
      target = tag_fixture(name: "implied target")

      parent
      |> Repo.preload(:implied_tags)
      |> Tag.changeset(%{"implied_tag_list" => source.name}, [source])
      |> Repo.update!()

      assert {:error, changeset} =
               Tags.update_tag_alias(admin, source.slug, %{"target_tag" => target.name})

      assert %{tag: ["is implied by other tags and cannot be aliased"]} = errors_on(changeset)
      assert Repo.reload!(source).aliased_tag_id == nil
    end

    test "a plain moderator lacks :alias and is unauthorized" do
      target = tag_fixture(name: "alias mod target")
      tag = tag_fixture()

      assert Tags.update_tag_alias(actor(moderator_user_fixture()), tag.slug, %{
               "target_tag" => target.name
             }) ==
               {:error, :unauthorized}

      assert Repo.reload!(tag).aliased_tag_id == nil
    end

    test "anonymous and regular users are unauthorized" do
      target = tag_fixture(name: "alias anon target")
      tag = tag_fixture()

      assert Tags.update_tag_alias(actor(), tag.slug, %{"target_tag" => target.name}) ==
               {:error, :unauthorized}

      assert Tags.update_tag_alias(actor(confirmed_user_fixture()), tag.slug, %{
               "target_tag" => target.name
             }) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.update_tag_alias(actor(admin_user_fixture()), "nonexistent-tag", %{
               "target_tag" => "x"
             }) ==
               {:error, :not_found}

      assert Tags.update_tag_alias(actor(moderator_user_fixture()), "nonexistent-tag", %{
               "target_tag" => "x"
             }) ==
               {:error, :not_found}
    end
  end

  describe "delete_tag_alias/2" do
    test "an admin queues a dealias and writes a moderation log" do
      target = tag_fixture(name: "dealias context target")

      tag =
        tag_fixture()
        |> Ecto.Changeset.change(aliased_tag_id: target.id)
        |> Repo.update!()

      assert {:ok, %Tag{} = returned} =
               Tags.delete_tag_alias(actor(admin_user_fixture()), tag.slug)

      assert returned.id == tag.id
      assert Repo.reload!(tag).aliased_tag_id == nil

      log = only_moderation_log!()
      assert log.type == "Tag.Alias:delete"
      assert log.subject_path == Paths.tag_path(tag)
      assert log.body == "Dealiased tag '#{tag.name}'"
    end

    test "a plain moderator lacks :alias and is unauthorized" do
      tag = tag_fixture()

      assert Tags.delete_tag_alias(actor(moderator_user_fixture()), tag.slug) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a tag that is not aliased is rejected before audit or queueing" do
      tag = tag_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Tags.delete_tag_alias(actor(admin_user_fixture()), tag.slug)

      assert %{aliased_tag: ["is not aliased"]} = errors_on(changeset)
      assert moderation_log_count() == 0
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.delete_tag_alias(actor(admin_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.delete_tag_alias(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "list_tag_details/2" do
    test "a moderator gets the spoilering/hiding filters and watching users" do
      tag = tag_fixture()

      spoiler_owner = confirmed_user_fixture()
      hide_owner = confirmed_user_fixture()
      spoiler_filter = filter_fixture(spoiler_owner, %{spoilered_tag_list: tag.name})
      hide_filter = filter_fixture(hide_owner, %{hidden_tag_list: tag.name})

      watcher =
        confirmed_user_fixture()
        |> Ecto.Changeset.change(watched_tag_ids: [tag.id])
        |> Repo.update!()

      assert {:ok, %TagDetail{} = detail} =
               Tags.list_tag_details(actor(moderator_user_fixture()), tag.slug)

      assert detail.tag.id == tag.id
      assert Enum.map(detail.filters_spoilering, & &1.id) == [spoiler_filter.id]
      assert Enum.map(detail.filters_hiding, & &1.id) == [hide_filter.id]
      assert Enum.map(detail.users_watching, & &1.id) == [watcher.id]
    end

    test "a fresh tag has empty usage lists" do
      tag = tag_fixture()

      assert {:ok, detail} = Tags.list_tag_details(actor(moderator_user_fixture()), tag.slug)
      assert detail.filters_spoilering == []
      assert detail.filters_hiding == []
      assert detail.users_watching == []
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.list_tag_details(actor(), "nonexistent-tag") == {:error, :not_found}

      assert Tags.list_tag_details(actor(confirmed_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.list_tag_details(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "edit_tag_image/2" do
    test "loads only the spoiler-image form dependencies" do
      tag = tag_fixture()

      assert {:ok, {%Tag{} = loaded, %Ecto.Changeset{}}} =
               Tags.edit_tag_image(actor(moderator_user_fixture()), tag.slug)

      assert loaded.id == tag.id
      assert Ecto.assoc_loaded?(loaded.implied_tags)
      refute Ecto.assoc_loaded?(loaded.aliases)
    end
  end

  describe "update_tag_image/3" do
    test "a moderator uploads the spoiler image and writes a moderation log" do
      tag = tag_fixture()

      assert {:ok, %Tag{} = updated} =
               Tags.update_tag_image(
                 actor(moderator_user_fixture()),
                 tag.slug,
                 media_png_upload()
               )

      assert updated.id == tag.id
      reloaded = Repo.reload!(tag)
      assert reloaded.image
      assert reloaded.image_mime_type == "image/png"

      log = only_moderation_log!()
      assert log.type == "Tag.Image:update"
      assert log.subject_path == Paths.tag_path(tag)
      assert log.body == "Updated image on tag '#{tag.name}'"
    end

    test "an upload with no file is a rejected changeset and writes no log" do
      tag = tag_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Tags.update_tag_image(actor(moderator_user_fixture()), tag.slug, nil)

      assert moderation_log_count() == 0
    end

    test "anonymous and regular users are unauthorized" do
      tag = tag_fixture()

      assert Tags.update_tag_image(actor(), tag.slug, media_png_upload()) ==
               {:error, :unauthorized}

      assert Tags.update_tag_image(
               actor(confirmed_user_fixture()),
               tag.slug,
               media_png_upload()
             ) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.update_tag_image(
               actor(admin_user_fixture()),
               "nonexistent-tag",
               media_png_upload()
             ) == {:error, :not_found}

      assert Tags.update_tag_image(
               actor(moderator_user_fixture()),
               "nonexistent-tag",
               media_png_upload()
             ) == {:error, :not_found}
    end
  end

  describe "delete_tag_image/2" do
    test "a moderator removes the spoiler image and writes a moderation log" do
      tag =
        tag_fixture()
        |> Ecto.Changeset.change(image: "2024/1/1/abc.png")
        |> Repo.update!()

      assert {:ok, %Tag{} = updated} =
               Tags.delete_tag_image(actor(moderator_user_fixture()), tag.slug)

      assert updated.id == tag.id
      assert Repo.reload!(tag).image == nil

      log = only_moderation_log!()
      assert log.type == "Tag.Image:delete"
      assert log.subject_path == Paths.tag_path(tag)
      assert log.body == "Removed image on tag '#{tag.name}'"
    end

    test "anonymous and regular users are unauthorized" do
      tag = tag_fixture()

      assert Tags.delete_tag_image(actor(), tag.slug) == {:error, :unauthorized}

      assert Tags.delete_tag_image(actor(confirmed_user_fixture()), tag.slug) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.delete_tag_image(actor(admin_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.delete_tag_image(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "create_tag_reindex/2" do
    test "an admin queues the reindex and gets the tag back" do
      tag = tag_fixture()

      assert {:ok, %Tag{} = returned} =
               Tags.create_tag_reindex(actor(admin_user_fixture()), tag.slug)

      assert returned.id == tag.id
      # No moderation log is written for a reindex.
      assert moderation_log_count() == 0
    end

    test "a plain moderator lacks :alias and is unauthorized" do
      tag = tag_fixture()

      assert Tags.create_tag_reindex(actor(moderator_user_fixture()), tag.slug) ==
               {:error, :unauthorized}
    end

    test "anonymous and regular users are unauthorized" do
      tag = tag_fixture()

      assert Tags.create_tag_reindex(actor(), tag.slug) == {:error, :unauthorized}

      assert Tags.create_tag_reindex(actor(confirmed_user_fixture()), tag.slug) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization" do
      assert Tags.create_tag_reindex(actor(admin_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}

      assert Tags.create_tag_reindex(actor(moderator_user_fixture()), "nonexistent-tag") ==
               {:error, :not_found}
    end
  end

  describe "create_tag_watch/2 and delete_tag_watch/2" do
    test "a signed-in user watches then unwatches a tag" do
      user = confirmed_user_fixture()
      tag = tag_fixture()

      assert {:ok, %Philomena.Users.User{} = watching} =
               Tags.create_tag_watch(actor(user), tag.slug)

      assert watching.watched_tag_ids == [tag.id]
      assert Repo.reload!(user).watched_tag_ids == [tag.id]

      assert {:ok, %Philomena.Users.User{}} = Tags.delete_tag_watch(actor(watching), tag.slug)
      assert Repo.reload!(user).watched_tag_ids == []
    end

    test "watching and unwatching an alias uses its canonical tag" do
      user = confirmed_user_fixture()
      canonical = tag_fixture(name: "watched canonical")

      alias_tag =
        tag_fixture(name: "watched alias")
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      assert {:ok, watching} = Tags.create_tag_watch(actor(user), alias_tag.slug)
      assert watching.watched_tag_ids == [canonical.id]

      assert {:ok, _} = Tags.delete_tag_watch(actor(watching), alias_tag.slug)
      assert Repo.reload!(user).watched_tag_ids == []
    end

    test "unwatching a tag that is not watched is an idempotent success" do
      user = confirmed_user_fixture()
      tag = tag_fixture()

      assert {:ok, %Philomena.Users.User{}} = Tags.delete_tag_watch(actor(user), tag.slug)
      assert Repo.reload!(user).watched_tag_ids == []
    end

    test "an unknown slug is not-found for both watch and unwatch" do
      user = confirmed_user_fixture()

      assert Tags.create_tag_watch(actor(user), "nonexistent-tag") == {:error, :not_found}
      assert Tags.delete_tag_watch(actor(user), "nonexistent-tag") == {:error, :not_found}
    end
  end

  describe "write access parity" do
    test "form loaders and their matching mutations reject a banned staff actor" do
      admin = admin_user_fixture()
      banned_actor = actor(admin, ban: %{})
      tag = tag_fixture(name: "banned tag source")
      target = tag_fixture(name: "banned tag target")

      assert Tags.edit_tag(banned_actor, tag.slug) == {:error, :ban}
      assert Tags.edit_tag_image(banned_actor, tag.slug) == {:error, :ban}
      assert Tags.edit_tag_alias(banned_actor, tag.slug) == {:error, :ban}

      assert Tags.update_tag(banned_actor, tag.slug, %{}) == {:error, :ban}
      assert Tags.update_tag_image(banned_actor, tag.slug, nil) == {:error, :ban}
      assert Tags.delete_tag_image(banned_actor, tag.slug) == {:error, :ban}

      assert Tags.update_tag_alias(banned_actor, tag.slug, %{"target_tag" => target.name}) ==
               {:error, :ban}

      assert Tags.delete_tag_alias(banned_actor, tag.slug) == {:error, :ban}
      assert Tags.create_tag_reindex(banned_actor, tag.slug) == {:error, :ban}
      assert Tags.delete_tag(banned_actor, tag.slug) == {:error, :ban}
      assert moderation_log_count() == 0
    end
  end

  describe "put_copy_tags/3" do
    test "copies only missing integer tag ids and increments their counters exactly once" do
      source = image_fixture(tags: "copy shared, copy source only")
      target = image_fixture(tags: "copy shared")

      shared =
        Repo.get_by!(Tag, name: "copy shared")
        |> Ecto.Changeset.change(images_count: 2)
        |> Repo.update!()

      source_only =
        Repo.get_by!(Tag, name: "copy source only")
        |> Ecto.Changeset.change(images_count: 1)
        |> Repo.update!()

      assert {:ok, %{copied_tag_ids: [copied_id]}} =
               Multi.new()
               |> Tags.put_copy_tags(source, target)
               |> Multi.transact()

      assert copied_id == source_only.id
      assert Repo.reload!(shared).images_count == 2
      assert Repo.reload!(source_only).images_count == 2

      target_tag_ids =
        target
        |> Repo.preload(:tags, force: true)
        |> Map.fetch!(:tags)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert target_tag_ids == Enum.sort([shared.id, source_only.id])
    end
  end

  describe "cleanup!/0" do
    test "removes empty tag changes and preserves changes with remaining tags" do
      empty = tag_fixture()
      kept = tag_fixture(category: "general")
      image = image_fixture()
      attribution = actor()

      empty_change =
        Repo.insert!(%Philomena.TagChanges.TagChange{
          image_id: image.id,
          ip: attribution.ip,
          fingerprint: attribution.fingerprint
        })

      shared_change =
        Repo.insert!(%Philomena.TagChanges.TagChange{
          image_id: image.id,
          ip: attribution.ip,
          fingerprint: attribution.fingerprint
        })

      Repo.insert_all(Philomena.TagChanges.TagChangeTag, [
        %{tag_change_id: empty_change.id, tag_id: empty.id, added: true},
        %{tag_change_id: shared_change.id, tag_id: empty.id, added: false},
        %{tag_change_id: shared_change.id, tag_id: kept.id, added: true}
      ])

      assert Tags.cleanup!() == [empty.id]

      refute Repo.get(Philomena.TagChanges.TagChange, empty_change.id)
      assert Repo.get(Philomena.TagChanges.TagChange, shared_change.id)
      assert [%{tag_id: tag_id}] = Repo.all(Philomena.TagChanges.TagChangeTag)
      assert tag_id == kept.id
      assert Tags.cleanup!() == []
    end

    test "deletes eligible tags once, returns their ids, and preserves meaningful tags" do
      empty = tag_fixture(name: "cleanup empty")

      kept =
        tag_fixture(name: "cleanup described")
        |> Ecto.Changeset.change(description: "Still useful")
        |> Repo.update!()

      assert [empty_id] = Tags.cleanup!()
      assert empty_id == empty.id
      refute Repo.get(Tag, empty.id)
      assert Repo.get(Tag, kept.id)
    end
  end

  describe "replace_aliases_in_implied_tags!/0" do
    test "replaces aliased implied tags and avoids duplicate canonical relationships" do
      parent = tag_fixture(name: "repair parent")
      alias_tag = tag_fixture(name: "repair alias")
      canonical = tag_fixture(name: "repair canonical")
      other = tag_fixture(name: "repair other")

      alias_tag
      |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
      |> Repo.update!()

      Repo.insert_all(Implication, [
        %{tag_id: parent.id, implied_tag_id: alias_tag.id},
        %{tag_id: parent.id, implied_tag_id: canonical.id},
        %{tag_id: parent.id, implied_tag_id: other.id}
      ])

      assert :ok = Tags.replace_aliases_in_implied_tags!()

      implication_ids =
        parent
        |> Repo.preload(:implied_tags, force: true)
        |> Map.fetch!(:implied_tags)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert implication_ids == Enum.sort([canonical.id, other.id])
    end

    test "does nothing when no implied tag is aliased" do
      parent = tag_fixture(name: "repair untouched parent")
      implied = tag_fixture(name: "repair untouched implied")

      Repo.insert_all(Implication, [%{tag_id: parent.id, implied_tag_id: implied.id}])

      assert :ok = Tags.replace_aliases_in_implied_tags!()

      assert [loaded] =
               parent
               |> Repo.preload(:implied_tags, force: true)
               |> Map.fetch!(:implied_tags)

      assert loaded.id == implied.id
    end
  end

  describe "Tag.creation_changeset/2 name length limit" do
    test "accepts a name of exactly the limit" do
      name = String.duplicate("a", @limit)

      assert {:ok, %Tag{name: ^name}} =
               %Tag{} |> Tag.creation_changeset(%{name: name}) |> Repo.insert()
    end

    test "rejects a name over the limit" do
      name = String.duplicate("a", @limit + 1)

      assert {:error, changeset} =
               %Tag{} |> Tag.creation_changeset(%{name: name}) |> Repo.insert()

      assert %{name: ["should be at most #{@limit} byte(s)"]} == errors_on(changeset)
    end

    test "counts bytes, not characters" do
      # 130 characters of "é" (2 bytes each in UTF-8) = 260 bytes
      name = String.duplicate("é", 130)

      assert {:error, changeset} =
               %Tag{} |> Tag.creation_changeset(%{name: name}) |> Repo.insert()

      assert %{name: [_message]} = errors_on(changeset)
    end
  end

  describe "parse_tag_list/1" do
    test "drops names over the limit and keeps the rest" do
      oversized = String.duplicate("a", @limit + 1)

      assert Tag.parse_tag_list("safe, #{oversized}, cute") == ["safe", "cute"]
    end

    test "keeps names of exactly the limit" do
      name = String.duplicate("a", @limit)

      assert Tag.parse_tag_list(name) == [name]
    end
  end

  describe "put_canonicalize_tag_name_sets/2" do
    test "does not create tags by default" do
      name = unique_tag_name()

      assert {:ok, %{canonical_tags: %{tags: []}}} =
               Multi.new()
               |> Tags.put_canonicalize_tag_name_sets([{:tags, [name], []}])
               |> Multi.transact()

      assert Repo.get_by(Tag, name: name) == nil
    end

    test "creates tags when requested and filters oversized names" do
      oversized = String.duplicate("a", @limit + 1)
      tag_names = Tag.parse_tag_list("safe, #{oversized}")

      assert {:ok, %{canonical_tags: %{tags: [%Tag{name: "safe"}]}}} =
               Multi.new()
               |> Tags.put_canonicalize_tag_name_sets([
                 {:tags, tag_names, allow_insert_new?: true}
               ])
               |> Multi.transact()

      assert Repo.get_by(Tag, name: oversized) == nil
    end
  end

  describe "put_lock_tag_alias_families/2" do
    test "returns the requested tags and their complete alias families" do
      canonical = tag_fixture(name: unique_tag_name())
      alias_tag = tag_fixture(name: unique_tag_name())

      alias_tag =
        alias_tag
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      assert {:ok, %{tags: tags, tag_alias_families: families}} =
               Multi.new()
               |> Tags.put_lock_tag_alias_families([alias_tag.id, canonical.id])
               |> Multi.transact()

      assert MapSet.new(Enum.map(tags, & &1.id)) == MapSet.new([alias_tag.id, canonical.id])

      for tag_id <- [alias_tag.id, canonical.id] do
        assert families[tag_id].canonical_id == canonical.id

        assert MapSet.new(families[tag_id].tag_ids) ==
                 MapSet.new([alias_tag.id, canonical.id])
      end
    end
  end
end
