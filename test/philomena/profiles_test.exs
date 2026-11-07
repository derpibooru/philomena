defmodule Philomena.ProfilesTest do
  @moduledoc """
  Context-level tests for `Philomena.Profiles`: the assembled profile page and
  the admin-only history views, each scoped to a viewer.

  `load_profile_page/4` is search-backed (the recent uploads/faves/artwork,
  comments, and posts strips come from a single multi-search), so the module is
  `async: false` and reindexes explicitly. The remaining functions are
  Postgres-only, but share the module.

  These pin the typed result shapes, the `:show_details` and owning-context
  authorization gates, stable missing/deactivated results, and pagination of
  sensitive histories.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.BansFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UserFingerprintsFixtures
  import Philomena.UserIpsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Images.Search.Scope
  alias Philomena.Posts.Post
  alias Philomena.Profiles
  alias Philomena.Profiles.AdminMetadata
  alias Philomena.Profiles.FingerprintHistory
  alias Philomena.Profiles.IpHistory
  alias Philomena.Profiles.ProfilePage
  alias Philomena.Repo
  alias Philomena.UserNameChanges.UserNameChange
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  @pagination %{page_number: 1, page_size: 25}
  @scrivener [page: 1, page_size: 25]

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

  defp scope do
    Scope.new(default_filter(), @pagination)
  end

  # The %Filter{} the profile page scopes its recent comments strip against; a
  # fresh system filter mirrors what ConnCase hands the web layer.
  defp current_filter do
    Philomena.FiltersFixtures.system_filter_fixture()
  end

  describe "show_profile/4" do
    setup do
      Search.clear_index!(Image)
      Search.clear_index!(Comment)
      Search.clear_index!(Post)
      :ok
    end

    test "assembles the full profile page with every struct key populated" do
      user = confirmed_user_fixture()
      upload = image_fixture(%{user_id: user.id})
      commented_image = image_fixture()
      comment = comment_fixture(commented_image, user)
      ban = user_ban_fixture(user)

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)

      assert {:ok, %ProfilePage{} = page} =
               Profiles.show_profile(actor(), scope(), current_filter(), user.slug)

      assert page.user.id == user.id

      # NOTE: the image strips are %Scrivener.Page{} (msearch_records returns named
      # page per definition), not bare lists, though the struct type doc says
      # list(). They are Enumerable, so mapping over them yields the records.
      assert %Scrivener.Page{} = page.recent_uploads
      assert %Scrivener.Page{} = page.recent_faves
      assert %Scrivener.Page{} = page.recent_artwork
      assert upload.id in Enum.map(page.recent_uploads, & &1.id)

      # recent_comments holds only comments whose images the viewer may see; the
      # comment is on a visible image, so it is present. It and recent_posts are
      # plain lists (both pass through Enum.filter).
      assert is_list(page.recent_comments)
      assert comment.id in Enum.map(page.recent_comments, & &1.id)
      assert is_list(page.recent_posts)
      assert is_list(page.recent_galleries)
      assert is_list(page.interactions)
      assert is_list(page.tags)

      # The 90-day statistics series carries one list of 90 daily values per
      # tracked counter.
      assert Map.keys(page.statistics) |> Enum.sort() ==
               Enum.sort([
                 :images_count,
                 :image_faves_count,
                 :comments_count,
                 :image_votes_count,
                 :metadata_updates_count,
                 :posts_count
               ])

      for {_key, series} <- page.statistics do
        assert length(series) == 90
      end

      assert is_map(page.watcher_counts)

      # The user's bans are listed newest first.
      assert ban.id in Enum.map(page.bans, & &1.id)
    end

    test "excludes a comment on a hidden image from recent_comments" do
      user = confirmed_user_fixture()
      hidden_image = image_fixture(%{hidden_from_users: true})
      comment = comment_fixture(hidden_image, moderator_user_fixture())

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)

      assert {:ok, %ProfilePage{} = page} =
               Profiles.show_profile(actor(), scope(), current_filter(), user.slug)

      # The comment itself is not hidden, so it matches the search, but an
      # anonymous viewer cannot see the hidden image, so it is dropped from the
      # strip the viewer receives.
      refute comment.id in Enum.map(page.recent_comments, & &1.id)
    end

    test "an unknown slug is not found for every viewer" do
      for viewer <- [actor(), actor(confirmed_user_fixture()), actor(admin_user_fixture())] do
        assert Profiles.show_profile(
                 viewer,
                 scope(),
                 current_filter(),
                 "no-such-user"
               ) == {:error, :not_found}
      end
    end

    test "a deactivated profile is not found for non-staff and loads for staff" do
      user = confirmed_user_fixture()

      user
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update!()

      assert Profiles.show_profile(
               actor(confirmed_user_fixture()),
               scope(),
               current_filter(),
               user.slug
             ) == {:error, :not_found}

      assert {:ok, %ProfilePage{} = page} =
               Profiles.show_profile(
                 actor(moderator_user_fixture()),
                 scope(),
                 current_filter(),
                 user.slug
               )

      assert page.user.id == user.id
    end
  end

  describe "load_admin_metadata/2" do
    test "a moderator sees the user's current filter and latest IP and fingerprint" do
      user = confirmed_user_fixture()
      user_ip_fixture(user, "203.0.113.55")
      user_fingerprint_fixture(user, "metadatafp")

      assert {:ok,
              %AdminMetadata{
                filter: _filter,
                last_ip: last_ip,
                last_fingerprint: last_fingerprint
              }} = Profiles.load_admin_metadata(actor(moderator_user_fixture()), user)

      assert to_string(last_ip.ip) == "203.0.113.55"
      assert last_fingerprint.fingerprint == "metadatafp"
    end

    test "a regular user sees no metadata" do
      assert Profiles.load_admin_metadata(
               actor(confirmed_user_fixture()),
               confirmed_user_fixture()
             ) == {:error, :unauthorized}
    end

    test "an anonymous viewer sees no metadata" do
      assert Profiles.load_admin_metadata(actor(), confirmed_user_fixture()) ==
               {:error, :unauthorized}
    end
  end

  describe "load_mod_notes/3" do
    # The renderer is handed the raw note list and returns one body per note; the
    # result pairs each preloaded note with its rendered body.
    defp renderer, do: fn notes -> Enum.map(notes, & &1.body) end

    test "a moderator sees the notes on the user, paired with rendered bodies" do
      moderator = moderator_user_fixture()
      user = confirmed_user_fixture()

      {:ok, note} =
        Philomena.ModNotes.create_mod_note(actor(moderator), %{
          "user_id" => user.id,
          "body" => "Watching this account"
        })

      assert {:ok, [{loaded_note, body}]} =
               Profiles.load_mod_notes(actor(moderator), user, renderer())

      assert loaded_note.id == note.id
      assert body == "Watching this account"
    end

    test "a regular user sees no notes" do
      assert Profiles.load_mod_notes(
               actor(confirmed_user_fixture()),
               confirmed_user_fixture(),
               renderer()
             ) == {:error, :unauthorized}
    end

    test "the profile-details gate applies before the mod-note permission" do
      assert Profiles.load_mod_notes(
               actor(assistant_user_fixture()),
               confirmed_user_fixture(),
               renderer()
             ) == {:error, :unauthorized}
    end
  end

  describe "load_name_changes/2" do
    test "a moderator sees the user's name changes, newest id first" do
      user = confirmed_user_fixture()
      older = Repo.insert!(%UserNameChange{user_id: user.id, name: "oldname"})
      newer = Repo.insert!(%UserNameChange{user_id: user.id, name: "newername"})

      assert {:ok, changes} = Profiles.load_name_changes(actor(moderator_user_fixture()), user)
      assert Enum.map(changes, & &1.id) == [newer.id, older.id]
    end

    test "a regular user sees no name changes" do
      assert Profiles.load_name_changes(
               actor(confirmed_user_fixture()),
               confirmed_user_fixture()
             ) == {:error, :unauthorized}
    end
  end

  describe "list_profile_ip_history/3" do
    test "a moderator loads the user's IPs and the other users on them" do
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()
      user_ip_fixture(subject, "203.0.113.40")
      user_ip_fixture(alias_user, "203.0.113.40")

      assert {:ok, %IpHistory{user: loaded, user_ips: user_ips, other_users: other_users}} =
               Profiles.list_profile_ip_history(
                 actor(moderator_user_fixture()),
                 subject.slug,
                 @scrivener
               )

      assert loaded.id == subject.id
      assert length(user_ips.entries) == 1

      shared_ip = hd(user_ips.entries).ip
      other_user_ids = other_users[shared_ip] |> Enum.map(& &1.user_id)
      assert alias_user.id in other_user_ids
      assert subject.id in other_user_ids
    end

    test "a regular user may not load IP history" do
      assert Profiles.list_profile_ip_history(
               actor(confirmed_user_fixture()),
               confirmed_user_fixture().slug,
               @scrivener
             ) ==
               {:error, :unauthorized}
    end

    test "an anonymous viewer may not load IP history" do
      assert Profiles.list_profile_ip_history(actor(), confirmed_user_fixture().slug, @scrivener) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not found before authorization for every viewer" do
      for viewer <- [actor(), actor(confirmed_user_fixture()), actor(moderator_user_fixture())] do
        assert Profiles.list_profile_ip_history(viewer, "no-such-user", @scrivener) ==
                 {:error, :not_found}
      end
    end

    test "paginates the subject history" do
      subject = confirmed_user_fixture()
      user_ip_fixture(subject, "203.0.113.41")
      user_ip_fixture(subject, "203.0.113.42")

      assert {:ok, %IpHistory{user_ips: page}} =
               Profiles.list_profile_ip_history(
                 actor(moderator_user_fixture()),
                 subject.slug,
                 page: 1,
                 page_size: 1
               )

      assert length(page.entries) == 1
      assert page.total_entries == 2
    end
  end

  describe "list_profile_fingerprint_history/3" do
    test "a moderator loads the user's fingerprints and the other users on them" do
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()
      user_fingerprint_fixture(subject, "sharedfp")
      user_fingerprint_fixture(alias_user, "sharedfp")

      assert {:ok,
              %FingerprintHistory{
                user: loaded,
                user_fingerprints: user_fingerprints,
                other_users: other_users
              }} =
               Profiles.list_profile_fingerprint_history(
                 actor(moderator_user_fixture()),
                 subject.slug,
                 @scrivener
               )

      assert loaded.id == subject.id
      assert length(user_fingerprints.entries) == 1

      other_user_ids = other_users["sharedfp"] |> Enum.map(& &1.user_id)
      assert alias_user.id in other_user_ids
      assert subject.id in other_user_ids
    end

    test "a regular user may not load fingerprint history" do
      assert Profiles.list_profile_fingerprint_history(
               actor(confirmed_user_fixture()),
               confirmed_user_fixture().slug,
               @scrivener
             ) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not found before authorization for every viewer" do
      for viewer <- [actor(), actor(confirmed_user_fixture()), actor(moderator_user_fixture())] do
        assert Profiles.list_profile_fingerprint_history(viewer, "no-such-user", @scrivener) ==
                 {:error, :not_found}
      end
    end
  end
end
