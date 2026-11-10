defmodule Philomena.ArtistLinksTest do
  @moduledoc """
  Context-level tests for the actor-first artist-link loaders and writers on
  `Philomena.ArtistLinks`.

  These pin the two-layer authorization the link routes preserve: the raw
  `ArtistLink` action (`:show`/`:edit`/`:update`) on the loaded link, followed
  by the mapped `:create_links`/`:edit_links` action on the profile `User`. The
  owner/unrelated/staff matrix is exercised against each layer, including the
  asymmetry where a profile owner may create and view their own links but not
  edit them.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ArtistLinksFixtures
  import Philomena.BadgesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.ArtistLinks
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Badges.Award
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo

  defp moderation_logs, do: Repo.all(ModerationLog)

  defp no_moderation_logs! do
    assert Repo.aggregate(ModerationLog, :count) == 0
  end

  # A truthy ban value in the shape production passes; only its presence matters
  # to the write-access and not-banned checks the loaders run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  defp artist_tag_fixture do
    tag_fixture(name: "artist:test-link-artist-#{System.unique_integer([:positive])}")
  end

  # A link owner with an all-unreserved slug, so a moderation-log subject_path
  # is identical to "/profiles/<slug>/artist_links/<id>" with no percent-encoding.
  defp link_owner_fixture do
    confirmed_user_fixture(%{name: "linkowner#{System.unique_integer([:positive])}"})
  end

  # Link params in the shape the artist-link form posts.
  defp link_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      "tag_name" => artist_tag_fixture().name,
      "uri" => "https://example.com/gallery-#{System.unique_integer([:positive])}"
    })
  end

  describe "list_artist_links/2" do
    test "the profile owner lists their own links" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, {loaded_user, links}} = ArtistLinks.list_artist_links(actor(user), user.slug)
      assert loaded_user.id == user.id
      assert Enum.map(links, & &1.id) == [link.id]
    end

    test "a moderator lists another user's links" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, {_user, links}} =
               ArtistLinks.list_artist_links(actor(moderator_user_fixture()), user.slug)

      assert Enum.map(links, & &1.id) == [link.id]
    end

    test "an unrelated user may not list another user's links" do
      user = confirmed_user_fixture()

      assert ArtistLinks.list_artist_links(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "an anonymous viewer may not list links" do
      assert ArtistLinks.list_artist_links(actor(), confirmed_user_fixture().slug) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before authorization for every actor" do
      assert ArtistLinks.list_artist_links(actor(confirmed_user_fixture()), "no-such-user") ==
               {:error, :not_found}

      assert ArtistLinks.list_artist_links(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "new_artist_link/2" do
    test "the profile owner gets a changeset" do
      user = confirmed_user_fixture()

      assert {:ok, {loaded_user, %Ecto.Changeset{data: %ArtistLink{}}}} =
               ArtistLinks.new_artist_link(actor(user), user.slug)

      assert loaded_user.id == user.id
    end

    test "a banned actor is rejected before any authorization" do
      user = confirmed_user_fixture()

      assert ArtistLinks.new_artist_link(actor(user, ban: @ban), user.slug) ==
               {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      user = confirmed_user_fixture()

      assert {:ok, _} = ArtistLinks.new_artist_link(actor(user, fingerprint: nil), user.slug)
    end

    test "an unrelated user may not open another user's new form" do
      user = confirmed_user_fixture()

      assert ArtistLinks.new_artist_link(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end
  end

  describe "create_artist_link/3" do
    test "the profile owner inserts an unverified link" do
      user = confirmed_user_fixture()

      assert {:ok, {loaded_user, %ArtistLink{} = link}} =
               ArtistLinks.create_artist_link(actor(user), user.slug, link_params())

      assert loaded_user.id == user.id
      assert Repo.get(ArtistLink, link.id).user_id == user.id
      assert link.aasm_state == "unverified"
    end

    test "an aliased tag resolves to its canonical tag" do
      user = confirmed_user_fixture()
      canonical = artist_tag_fixture()

      alias_tag =
        artist_tag_fixture()
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      assert {:ok, {_user, link}} =
               ArtistLinks.create_artist_link(
                 actor(user),
                 user.slug,
                 Map.merge(link_params(), %{"tag_name" => alias_tag.name})
               )

      assert link.tag_id == canonical.id
    end

    test "an actor with no fingerprint is unauthorized" do
      user = confirmed_user_fixture()

      assert ArtistLinks.create_artist_link(
               actor(user, fingerprint: nil),
               user.slug,
               link_params()
             ) == {:error, :unauthorized}
    end

    test "an unrelated user may not create a link on another profile" do
      user = confirmed_user_fixture()

      assert ArtistLinks.create_artist_link(
               actor(confirmed_user_fixture()),
               user.slug,
               link_params()
             ) == {:error, :unauthorized}
    end
  end

  describe "show_artist_link/3" do
    test "the profile owner views their own link" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, {loaded_user, loaded_link}} =
               ArtistLinks.show_artist_link(actor(user), user.slug, "#{link.id}")

      assert loaded_user.id == user.id
      assert loaded_link.id == link.id
    end

    test "a moderator views another user's link" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, {_user, loaded_link}} =
               ArtistLinks.show_artist_link(
                 actor(moderator_user_fixture()),
                 user.slug,
                 "#{link.id}"
               )

      assert loaded_link.id == link.id
    end

    test "a non-castable id is not-found" do
      user = confirmed_user_fixture()

      assert ArtistLinks.show_artist_link(actor(user), user.slug, "abc") ==
               {:error, :not_found}
    end

    test "a link cannot be shown through another profile slug" do
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      link = artist_link_fixture(owner, artist_tag_fixture())

      assert ArtistLinks.show_artist_link(
               actor(moderator_user_fixture()),
               other.slug,
               link.id
             ) == {:error, :not_found}
    end
  end

  describe "edit_artist_link/3" do
    test "a moderator loads the edit form" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, {loaded_link, %Ecto.Changeset{}}} =
               ArtistLinks.edit_artist_link(
                 actor(moderator_user_fixture()),
                 user.slug,
                 "#{link.id}"
               )

      assert loaded_link.id == link.id
    end

    test "the profile owner may not edit their own link" do
      # Owners get :create_links and :show on their own links, but neither :edit
      # on the link nor :edit_links on the profile, so editing is refused.
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert ArtistLinks.edit_artist_link(actor(user), user.slug, "#{link.id}") ==
               {:error, :unauthorized}
    end

    test "a non-castable id is not-found" do
      user = confirmed_user_fixture()

      assert ArtistLinks.edit_artist_link(
               actor(moderator_user_fixture()),
               user.slug,
               "abc"
             ) ==
               {:error, :not_found}
    end

    test "a link cannot be edited through another profile slug" do
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      link = artist_link_fixture(owner, artist_tag_fixture())

      assert ArtistLinks.edit_artist_link(
               actor(moderator_user_fixture()),
               other.slug,
               link.id
             ) == {:error, :not_found}
    end
  end

  describe "update_artist_link/4" do
    test "a moderator updates a link" do
      user = confirmed_user_fixture()
      tag = artist_tag_fixture()
      link = artist_link_fixture(user, tag)

      assert {:ok, {loaded_user, updated}} =
               ArtistLinks.update_artist_link(
                 actor(moderator_user_fixture()),
                 user.slug,
                 "#{link.id}",
                 %{"tag_name" => tag.name, "uri" => "https://example.com/updated-gallery"}
               )

      assert loaded_user.id == user.id
      assert updated.uri == "https://example.com/updated-gallery"
      assert Repo.get(ArtistLink, link.id).uri == "https://example.com/updated-gallery"
    end

    test "an aliased tag resolves to its canonical tag" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())
      canonical = artist_tag_fixture()

      alias_tag =
        artist_tag_fixture()
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      assert {:ok, {_user, updated}} =
               ArtistLinks.update_artist_link(
                 actor(moderator_user_fixture()),
                 user.slug,
                 "#{link.id}",
                 %{"tag_name" => alias_tag.name, "uri" => link.uri}
               )

      assert updated.tag_id == canonical.id
    end

    test "the profile owner may not update their own link" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert ArtistLinks.update_artist_link(
               actor(user),
               user.slug,
               "#{link.id}",
               %{"uri" => "https://example.com/updated-gallery"}
             ) == {:error, :unauthorized}
    end

    # A missing "tag_name" resolves to no tag, same as a name that matches
    # nothing, and the edit clears the link's tag.
    test "an update without a tag name clears the tag" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, {_loaded_user, updated}} =
               ArtistLinks.update_artist_link(
                 actor(moderator_user_fixture()),
                 user.slug,
                 "#{link.id}",
                 %{"uri" => "https://example.com/updated-gallery"}
               )

      assert updated.tag_id == nil
    end

    test "a mismatched profile slug does not update the link" do
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      link = artist_link_fixture(owner, artist_tag_fixture())

      assert ArtistLinks.update_artist_link(
               actor(moderator_user_fixture()),
               other.slug,
               link.id,
               %{"uri" => "https://example.com/not-applied"}
             ) == {:error, :not_found}

      assert Repo.get!(ArtistLink, link.id).uri == link.uri
    end
  end

  describe "list_admin_artist_links/3 authorization" do
    @pagination %{page_number: 1, page_size: 25}

    test "a moderator and an admin may list, an anonymous viewer and a regular user may not" do
      assert {:ok, %Scrivener.Page{}, %Ecto.Changeset{}} =
               ArtistLinks.list_admin_artist_links(
                 actor(moderator_user_fixture()),
                 %{},
                 @pagination
               )

      assert {:ok, %Scrivener.Page{}, %Ecto.Changeset{}} =
               ArtistLinks.list_admin_artist_links(actor(admin_user_fixture()), %{}, @pagination)

      assert ArtistLinks.list_admin_artist_links(actor(), %{}, @pagination) ==
               {:error, :unauthorized}

      assert ArtistLinks.list_admin_artist_links(
               actor(confirmed_user_fixture()),
               %{},
               @pagination
             ) ==
               {:error, :unauthorized}
    end
  end

  describe "list_admin_artist_links/3 listing modes" do
    @pagination %{page_number: 1, page_size: 25}

    test "the default listing shows only links awaiting moderation" do
      moderator = moderator_user_fixture()
      user = confirmed_user_fixture()
      pending = artist_link_fixture(user, artist_tag_fixture())
      verified = verified_artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, page, _changeset} =
               ArtistLinks.list_admin_artist_links(actor(moderator), %{}, @pagination)

      ids = Enum.map(page.entries, & &1.id)
      assert pending.id in ids
      refute verified.id in ids
    end

    test "an explicit state list includes every link regardless of state" do
      moderator = moderator_user_fixture()
      user = confirmed_user_fixture()
      pending = artist_link_fixture(user, artist_tag_fixture())
      verified = verified_artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, page, _changeset} =
               ArtistLinks.list_admin_artist_links(
                 actor(moderator),
                 %{"states" => ArtistLink.states()},
                 @pagination
               )

      ids = Enum.map(page.entries, & &1.id)
      assert pending.id in ids
      assert verified.id in ids
    end

    test "an empty state list does not filter links" do
      moderator = moderator_user_fixture()
      user = confirmed_user_fixture()
      pending = artist_link_fixture(user, artist_tag_fixture())
      verified = verified_artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, page, _changeset} =
               ArtistLinks.list_admin_artist_links(
                 actor(moderator),
                 %{"states" => []},
                 @pagination
               )

      ids = Enum.map(page.entries, & &1.id)
      assert pending.id in ids
      assert verified.id in ids
    end

    test "the text filter matches the link uri" do
      moderator = moderator_user_fixture()
      user = confirmed_user_fixture()

      wanted =
        artist_link_fixture(user, artist_tag_fixture(), %{
          "uri" => "https://match.example.com/needle"
        })

      _other =
        artist_link_fixture(user, artist_tag_fixture(), %{
          "uri" => "https://other.example.com/haystack"
        })

      assert {:ok, page, _changeset} =
               ArtistLinks.list_admin_artist_links(
                 actor(moderator),
                 %{"text" => "needle"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [wanted.id]
    end

    test "the text filter matches the profile user name" do
      moderator = moderator_user_fixture()

      wanted_user =
        confirmed_user_fixture(%{name: "lqmatchowner#{System.unique_integer([:positive])}"})

      other_user = confirmed_user_fixture()
      wanted = artist_link_fixture(wanted_user, artist_tag_fixture())
      _other = artist_link_fixture(other_user, artist_tag_fixture())

      assert {:ok, page, _changeset} =
               ArtistLinks.list_admin_artist_links(
                 actor(moderator),
                 %{"text" => wanted_user.name},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [wanted.id]
    end
  end

  describe "create_artist_link_verification/2" do
    test "a moderator verifies a link, awards the Artist badge, and writes a byte-exact log" do
      moderator = moderator_user_fixture()
      user = link_owner_fixture()
      badge = badge_fixture(%{title: "Artist"})
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, verified} =
               ArtistLinks.create_artist_link_verification(actor(moderator), "#{link.id}")

      assert verified.aasm_state == "verified"
      assert Repo.get(ArtistLink, link.id).aasm_state == "verified"

      # The verification awards the owner the badge titled "Artist".
      assert Repo.get_by(Award, badge_id: badge.id, user_id: user.id)

      assert [log] = moderation_logs()
      assert log.user_id == moderator.id
      assert log.type == "Admin.ArtistLink.Verification:create"
      assert log.body == "Verified artist link #{link.uri} created by #{user.name}"
      assert log.subject_path == "/profiles/#{user.slug}/artist_links/#{link.id}"
    end

    test "an admin verifies a link" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, verified} =
               ArtistLinks.create_artist_link_verification(
                 actor(admin_user_fixture()),
                 "#{link.id}"
               )

      assert verified.aasm_state == "verified"
    end

    test "a regular user is unauthorized and writes no log" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert ArtistLinks.create_artist_link_verification(
               actor(confirmed_user_fixture()),
               "#{link.id}"
             ) ==
               {:error, :unauthorized}

      assert Repo.get(ArtistLink, link.id).aasm_state == "unverified"
      no_moderation_logs!()
    end

    test "a non-castable id is not-found" do
      assert ArtistLinks.create_artist_link_verification(actor(moderator_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "an unknown integer id is not-found for every actor" do
      assert ArtistLinks.create_artist_link_verification(
               actor(moderator_user_fixture()),
               "2147483647"
             ) ==
               {:error, :not_found}

      assert ArtistLinks.create_artist_link_verification(
               actor(admin_user_fixture()),
               "2147483647"
             ) ==
               {:error, :not_found}
    end
  end

  describe "create_artist_link_contact/2" do
    test "a moderator marks a link as contacted and writes a byte-exact log" do
      moderator = moderator_user_fixture()
      user = link_owner_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, contacted} =
               ArtistLinks.create_artist_link_contact(actor(moderator), "#{link.id}")

      assert contacted.aasm_state == "contacted"
      assert Repo.get(ArtistLink, link.id).contacted_by_user_id == moderator.id

      assert [log] = moderation_logs()
      assert log.user_id == moderator.id
      assert log.type == "Admin.ArtistLink.Contact:create"
      assert log.body == "Contacted artist #{user.name} at #{link.uri}"
      assert log.subject_path == "/profiles/#{user.slug}/artist_links/#{link.id}"
    end

    test "a regular user is unauthorized and writes no log" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert ArtistLinks.create_artist_link_contact(actor(confirmed_user_fixture()), "#{link.id}") ==
               {:error, :unauthorized}

      assert Repo.get(ArtistLink, link.id).aasm_state == "unverified"
      no_moderation_logs!()
    end

    test "a non-castable id is not-found" do
      assert ArtistLinks.create_artist_link_contact(actor(moderator_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "an unknown integer id is not-found for every actor" do
      assert ArtistLinks.create_artist_link_contact(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert ArtistLinks.create_artist_link_contact(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "create_artist_link_reject/2" do
    test "a moderator rejects a link and writes a byte-exact log" do
      moderator = moderator_user_fixture()
      user = link_owner_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert {:ok, rejected} =
               ArtistLinks.create_artist_link_reject(actor(moderator), "#{link.id}")

      assert rejected.aasm_state == "rejected"
      assert Repo.get(ArtistLink, link.id).aasm_state == "rejected"

      assert [log] = moderation_logs()
      assert log.user_id == moderator.id
      assert log.type == "Admin.ArtistLink.Reject:create"
      assert log.body == "Rejected artist link #{link.uri} created by #{user.name}"
      assert log.subject_path == "/profiles/#{user.slug}/artist_links/#{link.id}"
    end

    test "a regular user is unauthorized and writes no log" do
      user = confirmed_user_fixture()
      link = artist_link_fixture(user, artist_tag_fixture())

      assert ArtistLinks.create_artist_link_reject(actor(confirmed_user_fixture()), "#{link.id}") ==
               {:error, :unauthorized}

      assert Repo.get(ArtistLink, link.id).aasm_state == "unverified"
      no_moderation_logs!()
    end

    test "a non-castable id is not-found" do
      assert ArtistLinks.create_artist_link_reject(actor(moderator_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "an unknown integer id is not-found for every actor" do
      assert ArtistLinks.create_artist_link_reject(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert ArtistLinks.create_artist_link_reject(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "transition write prerequisite" do
    test "verification, rejection, and contact reject banned and unattributed moderators" do
      moderator = moderator_user_fixture()
      link = artist_link_fixture(confirmed_user_fixture(), artist_tag_fixture())

      for operation <- [
            &ArtistLinks.create_artist_link_verification(&1, link.id),
            &ArtistLinks.create_artist_link_reject(&1, link.id),
            &ArtistLinks.create_artist_link_contact(&1, link.id)
          ] do
        assert operation.(actor(moderator, ban: @ban)) == {:error, :ban}
        assert operation.(actor(moderator, fingerprint: nil)) == {:error, :unauthorized}
      end

      assert Repo.get!(ArtistLink, link.id).aasm_state == "unverified"
      no_moderation_logs!()
    end
  end
end
