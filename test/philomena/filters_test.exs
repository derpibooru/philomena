defmodule Philomena.FiltersTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.Filters` functions.

  These pin the index/search viewer-visibility scoping, the `FilterPage` struct
  shape, the per-role authorization matrices on the form loaders and write
  paths (owner vs unrelated user vs admin, uniform malformed/absent ID handling,
  and banned and missing-fingerprint actors), explicit default selection, and
  idempotent publication.
  """

  use Philomena.DataCase, async: false

  # query_filters/3 and delete_filter/2 (via unindex) touch OpenSearch, so this
  # module follows the search rules: async: false, index cycled in setup.
  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Filters
  alias Philomena.Filters.Filter
  alias Philomena.Filters.FilterPage
  alias Philomena.Filters.ImageFilter
  alias Philomena.Images
  alias Philomena.Images.Filtering
  alias Philomena.Repo
  alias Philomena.Users.User
  alias PhilomenaQuery.Parse.Evaluator
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to the write-access checks
  # the tag toggles run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  @pagination %{page_number: 1, page_size: 25}

  setup do
    Search.clear_index!(Filter)
    :ok
  end

  describe "compile_image_filter/3" do
    test "compiles the effective search and display policy" do
      image = image_fixture(tags: "safe") |> Repo.preload(tags: :aliases)
      [safe] = image.tags

      current = %Filter{
        hidden_tag_ids: [],
        spoilered_tag_ids: [safe.id],
        hidden_complex_str: "score.lt:0",
        spoilered_complex_str: "faves.gt:10"
      }

      forced = %Filter{hidden_tag_ids: [safe.id], hidden_complex_str: "upvotes.lt:0"}

      assert %ImageFilter{} =
               image_filter =
               Filters.compile_image_filter(actor(), current, forced)

      assert safe.id in image_filter.display_tag_ids
      assert Images.filter_or_spoiler_hits?(image, image_filter)

      assert %{bool: %{should: [%{terms: %{tag_ids: [safe_id]}}, _complex]}} =
               image_filter.query

      assert safe_id == safe.id
    end

    test "an invalid hidden expression hides every image" do
      document = Filtering.document(Repo.preload(image_fixture(), tags: :aliases))

      for {current_filter, forced_filter} <- [
            {%Filter{hidden_complex_str: "("}, nil},
            {nil, %Filter{hidden_complex_str: "("}}
          ] do
        image_filter = Filters.compile_image_filter(actor(), current_filter, forced_filter)

        assert Evaluator.hits?(document, image_filter.query)
        assert [{:hidden_complex_str, _message}] = image_filter.errors
      end
    end

    test "a spoiler expression the viewer cannot use spoilers images without hiding them" do
      image = Repo.preload(image_fixture(), tags: :aliases)
      current = %Filter{spoilered_complex_str: "my:faves"}

      image_filter = Filters.compile_image_filter(actor(), current, nil)

      refute Evaluator.hits?(Filtering.document(image), image_filter.query)
      assert Images.filter_or_spoiler_hits?(image, image_filter)
      assert [{:spoilered_complex_str, _message}] = image_filter.errors
    end

    test "an empty selection excludes and spoilers nothing" do
      assert %ImageFilter{} =
               image_filter =
               Filters.compile_image_filter(actor(), nil, nil)

      assert image_filter.display_tag_ids == []
      assert image_filter.errors == []

      assert image_filter.query == %{
               bool: %{
                 should: [
                   %{terms: %{tag_ids: []}},
                   %{bool: %{should: [%{match_none: %{}}, %{match_none: %{}}]}}
                 ]
               }
             }
    end
  end

  describe "list_filters/1" do
    test "an anonymous visitor gets no personal filters, only system filters" do
      system = system_filter_fixture()

      assert {:ok, {nil, system_filters}} = Filters.list_filters(actor(), @pagination)
      assert system.id in Enum.map(system_filters, & &1.id)
    end

    test "a signed-in user gets their own filters and the system filters" do
      user = confirmed_user_fixture()
      mine = filter_fixture(user)
      _theirs = filter_fixture(confirmed_user_fixture())
      system = system_filter_fixture()

      assert {:ok, {my_filters, system_filters}} = Filters.list_filters(actor(user), @pagination)

      my_ids = Enum.map(my_filters, & &1.id)
      assert mine.id in my_ids
      # Only the viewer's own filters land in the first list.
      assert my_filters |> Enum.map(& &1.user_id) |> Enum.uniq() == [user.id]

      assert system.id in Enum.map(system_filters, & &1.id)
    end

    test "the returned filters carry their :user preloaded" do
      user = confirmed_user_fixture()
      filter_fixture(user)

      {:ok, {mine, _system}} = Filters.list_filters(actor(user), @pagination)
      refute match?(%Ecto.Association.NotLoaded{}, Enum.at(mine, 0).user)
    end
  end

  describe "query_filters/3" do
    test "an anonymous viewer finds public and system filters but not private ones" do
      public = filter_fixture(confirmed_user_fixture(), %{public: true})
      private = filter_fixture(confirmed_user_fixture())
      SearchHelpers.reindex_all!(Filter)

      assert {:ok, page} = Filters.query_filters(actor(), "*", @pagination)

      ids = Enum.map(page.entries, & &1.id)
      assert public.id in ids
      refute private.id in ids
    end

    test "a signed-in user additionally finds their own private filters" do
      user = confirmed_user_fixture()
      mine = filter_fixture(user)
      theirs = filter_fixture(confirmed_user_fixture())
      SearchHelpers.reindex_all!(Filter)

      assert {:ok, page} = Filters.query_filters(actor(user), "*", @pagination)

      ids = Enum.map(page.entries, & &1.id)
      assert mine.id in ids
      refute theirs.id in ids
    end

    test "a moderator finds private filters consistently with their show grant" do
      moderator = moderator_user_fixture()
      theirs = filter_fixture(confirmed_user_fixture())
      SearchHelpers.reindex_all!(Filter)

      assert {:ok, page} = Filters.query_filters(actor(moderator), "*", @pagination)
      assert theirs.id in Enum.map(page.entries, & &1.id)
    end

    test "restricting the query to a name finds that filter" do
      user = confirmed_user_fixture()
      mine = filter_fixture(user)
      SearchHelpers.reindex_all!(Filter)

      assert {:ok, page} = Filters.query_filters(actor(user), "name:#{mine.name}", @pagination)
      assert mine.id in Enum.map(page.entries, & &1.id)
    end

    test "a malformed query returns the compiler error" do
      assert {:error, msg} = Filters.query_filters(actor(), "name:(", @pagination)
      assert is_binary(msg)
    end
  end

  describe "indexing services" do
    test "perform_reindex/2 makes the matching filter searchable" do
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      assert :ok = Filters.perform_reindex(:id, [filter.id])
      :ok = Search.refresh_index!(Filter)
      assert {:ok, page} = Filters.query_filters(actor(), "name:#{filter.name}", @pagination)
      assert filter.id in Enum.map(page.entries, & &1.id)
    end

    test "indexing_preloads/0 includes the filter owner" do
      filter = filter_fixture(confirmed_user_fixture())

      loaded = Repo.preload(filter, Filters.indexing_preloads())

      refute match?(%Ecto.Association.NotLoaded{}, loaded.user)
    end
  end

  describe "show_filter_page/2" do
    test "an anonymous viewer loads a system filter's page" do
      system = system_filter_fixture()

      assert {:ok, %FilterPage{filter: filter, spoilered_tags: [], hidden_tags: []}} =
               Filters.show_filter_page(actor(), "#{system.id}")

      assert filter.id == system.id
      # The filter carries its :user preloaded for the page.
      refute match?(%Ecto.Association.NotLoaded{}, filter.user)
    end

    test "the owner loads their private filter's page with tags ordered by name" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      zed = tag_fixture(%{name: "zed tag"})
      abe = tag_fixture(%{name: "abe tag"})

      {:ok, filter} = Filters.create_filter_hide(actor(user), filter, zed.slug)
      {:ok, filter} = Filters.create_filter_hide(actor(user), filter, abe.slug)

      assert {:ok, %FilterPage{hidden_tags: hidden, spoilered_tags: []}} =
               Filters.show_filter_page(actor(user), "#{filter.id}")

      # Tags come back ordered by name ascending.
      assert Enum.map(hidden, & &1.name) == ["abe tag", "zed tag"]
    end

    test "an anonymous viewer cannot load another user's private filter" do
      filter = filter_fixture(confirmed_user_fixture())

      assert Filters.show_filter_page(actor(), "#{filter.id}") == {:error, :unauthorized}
    end

    test "a non-castable id is not-found" do
      assert Filters.show_filter_page(actor(), "not-a-number") == {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Filters.show_filter_page(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Filters.show_filter_page(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end
  end

  describe "new_filter/2" do
    test "a signed-in user with no base filter gets a blank changeset" do
      assert {:ok, %Ecto.Changeset{data: %Filter{} = data}} =
               Filters.new_filter(actor(confirmed_user_fixture()), nil)

      assert data.id == nil
    end

    test "basing a new filter on a visible filter prefills its tag lists" do
      owner = confirmed_user_fixture()
      source = filter_fixture(owner, %{public: true})
      tag = tag_fixture()
      {:ok, source} = Filters.create_filter_hide(actor(owner), source, tag.slug)

      assert {:ok, %Ecto.Changeset{data: %Filter{} = data}} =
               Filters.new_filter(actor(confirmed_user_fixture()), "#{source.id}")

      assert tag.id in data.hidden_tag_ids
    end

    test "basing a new filter on an unknown id yields a blank form" do
      assert {:ok, %Ecto.Changeset{data: %Filter{hidden_tag_ids: []}}} =
               Filters.new_filter(actor(confirmed_user_fixture()), "999999999")
    end

    test "basing a new filter on a malformed id yields a blank form" do
      assert {:ok, %Ecto.Changeset{data: %Filter{hidden_tag_ids: []}}} =
               Filters.new_filter(actor(confirmed_user_fixture()), "not-an-id")
    end

    test "an anonymous actor is unauthorized" do
      assert Filters.new_filter(actor(), nil) == {:error, :unauthorized}
    end
  end

  describe "edit_filter/2" do
    test "the owner loads their filter paired with an edit changeset" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert {:ok, {%Filter{} = loaded, %Ecto.Changeset{} = changeset}} =
               Filters.edit_filter(actor(user), "#{filter.id}")

      assert loaded.id == filter.id
      assert changeset.data.id == filter.id
    end

    test "an unrelated user is unauthorized" do
      filter = filter_fixture(confirmed_user_fixture())

      assert Filters.edit_filter(actor(confirmed_user_fixture()), "#{filter.id}") ==
               {:error, :unauthorized}
    end

    test "a non-castable id is not-found" do
      assert Filters.edit_filter(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Filters.edit_filter(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Filters.edit_filter(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_filter/3" do
    test "the owner renames their filter" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert {:ok, %Filter{}} =
               Filters.update_filter(actor(user), "#{filter.id}", %{"name" => "Renamed Filter"})

      assert Repo.reload!(filter).name == "Renamed Filter"
    end

    test "an admin updates another user's filter" do
      filter = filter_fixture(confirmed_user_fixture())

      assert {:ok, %Filter{}} =
               Filters.update_filter(actor(admin_user_fixture()), "#{filter.id}", %{
                 "name" => "Admin Renamed"
               })

      assert Repo.reload!(filter).name == "Admin Renamed"
    end

    test "an admin cannot rename the Default system filter" do
      default = system_filter_fixture(%{name: "Default"})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Filters.update_filter(actor(admin_user_fixture()), "#{default.id}", %{
                 "name" => "Renamed Default"
               })

      refute changeset.valid?
      assert {"cannot be changed for the system-wide default filter", _} = changeset.errors[:name]
      assert Repo.reload!(default).name == "Default"
    end

    test "an admin can update the Default system filter without renaming it" do
      default = system_filter_fixture(%{name: "Default"})

      assert {:ok, %Filter{} = updated} =
               Filters.update_filter(actor(admin_user_fixture()), "#{default.id}", %{
                 "description" => "Updated default filter"
               })

      assert updated.name == "Default"
      assert updated.description == "Updated default filter"
    end

    test "an invalid name is a rejected changeset" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Filters.update_filter(actor(user), "#{filter.id}", %{"name" => ""})

      refute changeset.valid?
      assert changeset.errors[:name]
    end

    test "an unrelated user is unauthorized and leaves the row unchanged" do
      filter = filter_fixture(confirmed_user_fixture())

      assert Filters.update_filter(actor(confirmed_user_fixture()), "#{filter.id}", %{
               "name" => "Hijacked"
             }) == {:error, :unauthorized}

      assert Repo.reload!(filter).name == filter.name
    end

    test "a non-castable id is not-found" do
      assert Filters.update_filter(actor(confirmed_user_fixture()), "abc", %{"name" => "x"}) ==
               {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Filters.update_filter(actor(confirmed_user_fixture()), "999999999", %{"name" => "x"}) ==
               {:error, :not_found}

      assert Filters.update_filter(actor(admin_user_fixture()), "999999999", %{"name" => "x"}) ==
               {:error, :not_found}
    end
  end

  describe "delete_filter/2" do
    test "the owner deletes their filter" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert {:ok, %Filter{} = deleted} = Filters.delete_filter(actor(user), "#{filter.id}")
      assert deleted.id == filter.id
      assert Repo.reload(filter) == nil
    end

    test "a filter used as a forced filter returns a rejected changeset" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      user
      |> User.force_filter_changeset(%{"forced_filter_id" => filter.id})
      |> Repo.update!()

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Filters.delete_filter(actor(user), "#{filter.id}")

      assert Repo.reload!(filter).id == filter.id
    end

    test "an unrelated user is unauthorized and leaves the row" do
      filter = filter_fixture(confirmed_user_fixture())

      assert Filters.delete_filter(actor(confirmed_user_fixture()), "#{filter.id}") ==
               {:error, :unauthorized}

      refute Repo.reload(filter) == nil
    end

    test "a non-castable id is not-found" do
      assert Filters.delete_filter(actor(confirmed_user_fixture()), "abc") == {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Filters.delete_filter(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Filters.delete_filter(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end
  end

  describe "create_filter_public/2" do
    test "the owner makes their private filter public" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      refute filter.public

      assert {:ok, %Filter{public: true}} =
               Filters.create_filter_public(actor(user), "#{filter.id}")

      assert Repo.reload!(filter).public
    end

    test "making an already-public filter public again is an idempotent success" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user, %{public: true})

      assert {:ok, %Filter{public: true}} =
               Filters.create_filter_public(actor(user), "#{filter.id}")
    end

    test "an unrelated user is unauthorized" do
      filter = filter_fixture(confirmed_user_fixture())

      assert Filters.create_filter_public(actor(confirmed_user_fixture()), "#{filter.id}") ==
               {:error, :unauthorized}
    end

    test "a non-castable id is not-found" do
      assert Filters.create_filter_public(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Filters.create_filter_public(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Filters.create_filter_public(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_current_filter/2" do
    test "a signed-in user switches to their own filter, persisting the choice" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert {:ok, %Filter{} = switched} =
               Filters.update_current_filter(actor(user), "#{filter.id}")

      assert switched.id == filter.id
      assert Repo.get!(User, user.id).current_filter_id == filter.id
    end

    test "a signed-in user is not authorized to switch to an unowned private filter" do
      user = confirmed_user_fixture()
      others = filter_fixture(confirmed_user_fixture())

      assert {:error, :unauthorized} =
               Filters.update_current_filter(actor(user), "#{others.id}")
    end

    test "an anonymous visitor gets the resolved filter back without persistence" do
      public = filter_fixture(confirmed_user_fixture(), %{public: true})

      assert {:ok, %Filter{} = switched} = Filters.update_current_filter(actor(), "#{public.id}")
      assert switched.id == public.id
    end

    test "an anonymous visitor is not authorized to switch to a private filter" do
      private = filter_fixture(confirmed_user_fixture())

      assert {:error, :unauthorized} = Filters.update_current_filter(actor(), "#{private.id}")
    end

    test "a well-formed id naming no row is not-found" do
      assert Filters.update_current_filter(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}
    end

    test "a non-castable id is not-found" do
      assert Filters.update_current_filter(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a nil id explicitly switches to the default filter" do
      default = system_filter_fixture(%{name: "Default"})
      user = confirmed_user_fixture()

      assert {:ok, %Filter{} = switched} = Filters.update_current_filter(actor(user), nil)
      assert switched.id == default.id
      assert Repo.get!(User, user.id).current_filter_id == default.id
    end

    test "switching the current filter leaves the forced filter unchanged" do
      user = confirmed_user_fixture()
      forced = filter_fixture(user)
      selected = filter_fixture(user)

      user =
        user
        |> User.force_filter_changeset(%{"forced_filter_id" => forced.id})
        |> Repo.update!()

      assert {:ok, %Filter{id: selected_id}} =
               Filters.update_current_filter(actor(user), selected.id)

      assert selected_id == selected.id
      assert Repo.get!(User, user.id).forced_filter_id == forced.id
    end
  end

  describe "recent_and_user_filters/1" do
    test "a user with a full recent list still sees their own filters" do
      user = confirmed_user_fixture()
      own_filters = [filter_fixture(user), filter_fixture(user)]
      recent_filters = for _ <- 1..10, do: system_filter_fixture()

      user =
        Enum.reduce(recent_filters, user, fn filter, user ->
          user |> User.filter_changeset(filter) |> Repo.update!()
        end)

      assert {:ok, selection} = Filters.recent_and_user_filters(actor(user))

      assert Enum.map(selection.recent_filters, & &1.id) ==
               Enum.reverse(Enum.map(recent_filters, & &1.id))

      assert Enum.map(selection.user_filters, & &1.id) == Enum.map(own_filters, & &1.id)
    end

    test "an anonymous visitor is unauthorized" do
      assert Filters.recent_and_user_filters(actor()) == {:error, :unauthorized}
    end
  end

  describe "load_selected_filters/2" do
    test "an anonymous malformed cookie selection falls back to the default" do
      default = system_filter_fixture(%{name: "Default"})

      assert {:ok, %{current_filter: current, forced_filter: nil}} =
               Filters.load_selected_filters(actor(), "not-an-id")

      assert current.id == default.id
    end

    test "a signed-in user gets a persisted default and their forced filter" do
      default = system_filter_fixture(%{name: "Default"})
      user = confirmed_user_fixture()
      forced = filter_fixture(user)

      user =
        user
        |> User.force_filter_changeset(%{"forced_filter_id" => forced.id})
        |> Repo.update!()

      assert {:ok, %{current_filter: current, forced_filter: loaded_forced}} =
               Filters.load_selected_filters(actor(user), nil)

      assert current.id == default.id
      assert loaded_forced.id == forced.id
      assert Repo.get!(User, user.id).current_filter_id == default.id
    end
  end

  describe "create_filter/2" do
    test "a signed-in user creates a filter attributed to themselves" do
      user = confirmed_user_fixture()

      assert {:ok, %Filter{} = filter} =
               Filters.create_filter(actor(user), %{"name" => "My New Filter"})

      assert filter.user_id == user.id
      assert filter.name == "My New Filter"
    end

    test "a blank name is a rejected changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Filters.create_filter(actor(confirmed_user_fixture()), %{"name" => ""})

      refute changeset.valid?
      assert changeset.errors[:name]
    end

    test "an anonymous actor is unauthorized" do
      assert Filters.create_filter(actor(), %{"name" => "x"}) == {:error, :unauthorized}
    end
  end

  describe "create_filter_hide/3 and delete_filter_hide/3" do
    test "the owner hides then unhides a tag by slug" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      tag = tag_fixture()

      assert {:ok, %Filter{} = hidden} = Filters.create_filter_hide(actor(user), filter, tag.slug)
      assert tag.id in hidden.hidden_tag_ids

      assert {:ok, %Filter{} = shown} = Filters.delete_filter_hide(actor(user), hidden, tag.slug)
      refute tag.id in shown.hidden_tag_ids
    end

    test "an unknown tag slug is not-found" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert Filters.create_filter_hide(actor(user), filter, "no-such-tag") ==
               {:error, :not_found}
    end

    test "an unrelated user is unauthorized" do
      filter = filter_fixture(confirmed_user_fixture())
      tag = tag_fixture()

      assert Filters.create_filter_hide(actor(confirmed_user_fixture()), filter, tag.slug) ==
               {:error, :unauthorized}
    end

    test "a banned actor is rejected before authorization, even with a good slug" do
      # verify_write_access runs first and decides the ban before the filter
      # authorization, so a banned owner is {:error, :ban}.
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      tag = tag_fixture()

      assert Filters.create_filter_hide(actor(user, ban: @ban), filter, tag.slug) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      tag = tag_fixture()

      assert Filters.create_filter_hide(actor(user, fingerprint: nil), filter, tag.slug) ==
               {:error, :unauthorized}
    end

    test "the ban wins over a missing fingerprint" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      tag = tag_fixture()

      assert Filters.create_filter_hide(
               actor(user, ban: @ban, fingerprint: nil),
               filter,
               tag.slug
             ) ==
               {:error, :ban}
    end
  end

  describe "create_filter_spoiler/3 and delete_filter_spoiler/3" do
    test "the owner spoilers then unspoilers a tag by slug" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      tag = tag_fixture()

      assert {:ok, %Filter{} = spoilered} =
               Filters.create_filter_spoiler(actor(user), filter, tag.slug)

      assert tag.id in spoilered.spoilered_tag_ids

      assert {:ok, %Filter{} = plain} =
               Filters.delete_filter_spoiler(actor(user), spoilered, tag.slug)

      refute tag.id in plain.spoilered_tag_ids
    end

    test "an unknown tag slug is not-found" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      assert Filters.create_filter_spoiler(actor(user), filter, "no-such-tag") ==
               {:error, :not_found}
    end

    test "an unrelated user is unauthorized" do
      filter = filter_fixture(confirmed_user_fixture())
      tag = tag_fixture()

      assert Filters.create_filter_spoiler(actor(confirmed_user_fixture()), filter, tag.slug) ==
               {:error, :unauthorized}
    end

    test "a banned actor is rejected" do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)
      tag = tag_fixture()

      assert Filters.create_filter_spoiler(actor(user, ban: @ban), filter, tag.slug) ==
               {:error, :ban}
    end
  end

  describe "write access" do
    setup do
      user = confirmed_user_fixture()
      filter = filter_fixture(user)

      forms = [
        new: fn actor -> Filters.new_filter(actor, nil) end,
        edit: fn actor -> Filters.edit_filter(actor, filter.id) end
      ]

      mutations = [
        create: fn actor -> Filters.create_filter(actor, %{"name" => "Created"}) end,
        update: fn actor -> Filters.update_filter(actor, filter.id, %{"name" => "Updated"}) end,
        publish: fn actor -> Filters.create_filter_public(actor, filter.id) end,
        delete: fn actor -> Filters.delete_filter(actor, filter.id) end
      ]

      %{user: user, forms: forms, mutations: mutations}
    end

    test "all form and mutation entry points reject a banned actor first", context do
      banned_actor = actor(context.user, ban: @ban)

      for {operation, invoke} <- context.forms ++ context.mutations do
        assert invoke.(banned_actor) == {:error, :ban},
               "expected #{operation} to reject a banned actor"
      end
    end

    test "forms load without a fingerprint", context do
      unidentified_actor = actor(context.user, fingerprint: nil)

      for {operation, invoke} <- context.forms do
        assert {:ok, _} = invoke.(unidentified_actor),
               "expected #{operation} to load without a fingerprint"
      end
    end

    test "mutations reject a missing fingerprint", context do
      unidentified_actor = actor(context.user, fingerprint: nil)

      for {operation, invoke} <- context.mutations do
        assert invoke.(unidentified_actor) == {:error, :unauthorized},
               "expected #{operation} to reject an actor without a fingerprint"
      end
    end
  end
end
