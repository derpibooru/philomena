defmodule Philomena.SourceChangesTest do
  @moduledoc "Context-level tests for the actor-scoped SourceChanges read boundary."

  use Philomena.DataCase, async: true

  alias Philomena.SourceChanges
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.SourceChanges.QueryForm
  alias Philomena.SourceChanges.SourceChangePage
  alias Philomena.Repo
  alias Scrivener.Page

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.ImagesFixtures
  import Philomena.SourceChangesFixtures
  import Philomena.UsersFixtures

  @pagination [page: 1, page_size: 25]

  describe "list_image_source_changes/3" do
    test "an anonymous actor lists a public image's source changes newest-first" do
      image = image_fixture()
      older = source_change_fixture(image)
      newer = source_change_fixture(image)

      assert {:ok, %SourceChangePage{target: loaded_image, source_changes: %Page{} = page}, _} =
               SourceChanges.list_image_source_changes(
                 actor(),
                 to_string(image.id),
                 %{},
                 @pagination
               )

      assert loaded_image.id == image.id
      assert Enum.map(page.entries, & &1.id) == [newer.id, older.id]
    end

    test "a regular user lists a public image's source changes" do
      user = confirmed_user_fixture()
      image = image_fixture()
      change = source_change_fixture(image)

      assert {:ok, %SourceChangePage{target: loaded_image, source_changes: page}, _} =
               SourceChanges.list_image_source_changes(
                 actor(user),
                 to_string(image.id),
                 %{},
                 @pagination
               )

      assert loaded_image.id == image.id
      assert Enum.map(page.entries, & &1.id) == [change.id]
    end

    test "the result preloads each change's user" do
      user = confirmed_user_fixture()
      image = image_fixture()
      source_change_fixture(image, user_id: user.id)

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_image_source_changes(
                 actor(),
                 to_string(image.id),
                 %{},
                 @pagination
               )

      [entry] = page.entries
      assert entry.user.id == user.id
    end

    test "page_size caps the entries and reports the total" do
      image = image_fixture()
      for _ <- 1..3, do: source_change_fixture(image)

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_image_source_changes(actor(), to_string(image.id), %{},
                 page: 1,
                 page_size: 2
               )

      assert page.page_size == 2
      assert length(page.entries) == 2
      assert page.total_entries == 3
    end

    test "an image with no source changes yields an empty page" do
      image = image_fixture()

      assert {:ok, %SourceChangePage{target: loaded_image, source_changes: page}, _} =
               SourceChanges.list_image_source_changes(
                 actor(),
                 to_string(image.id),
                 %{},
                 @pagination
               )

      assert loaded_image.id == image.id
      assert page.entries == []
      assert page.total_entries == 0
    end

    test "returns the normalized query changeset" do
      image = image_fixture()

      assert {:ok, %SourceChangePage{}, %Ecto.Changeset{data: %QueryForm{added: true}}} =
               SourceChanges.list_image_source_changes(
                 actor(),
                 image.id,
                 %{"added" => "1"},
                 @pagination
               )
    end

    test "returns a changeset for an invalid filter" do
      image = image_fixture()

      assert {:error, %Ecto.Changeset{valid?: false}} =
               SourceChanges.list_image_source_changes(
                 actor(),
                 image.id,
                 %{"added" => "invalid"},
                 @pagination
               )
    end

    test "accepts an integer id" do
      image = image_fixture()
      change = source_change_fixture(image)

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_image_source_changes(actor(), image.id, %{}, @pagination)

      assert Enum.map(page.entries, & &1.id) == [change.id]
    end

    test "an unknown well-formed id is not found for every actor" do
      assert SourceChanges.list_image_source_changes(actor(), "2147483647", %{}, @pagination) ==
               {:error, :not_found}

      assert SourceChanges.list_image_source_changes(
               actor(confirmed_user_fixture()),
               "2147483647",
               %{},
               @pagination
             ) == {:error, :not_found}

      assert SourceChanges.list_image_source_changes(
               actor(moderator_user_fixture()),
               "2147483647",
               %{},
               @pagination
             ) == {:error, :not_found}

      assert SourceChanges.list_image_source_changes(
               actor(admin_user_fixture()),
               "2147483647",
               %{},
               @pagination
             ) == {:error, :not_found}
    end

    test "a hidden image is forbidden to a regular user and visible to a moderator" do
      image = image_fixture(hidden_from_users: true)
      change = source_change_fixture(image)

      assert SourceChanges.list_image_source_changes(
               actor(confirmed_user_fixture()),
               image.id,
               %{},
               @pagination
             ) == {:error, :unauthorized}

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_image_source_changes(
                 actor(moderator_user_fixture()),
                 image.id,
                 %{},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [change.id]
    end

    test "a non-castable id is not found" do
      assert SourceChanges.list_image_source_changes(actor(), "not-a-number", %{}, @pagination) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, ahead of any authorization.
      assert SourceChanges.list_image_source_changes(
               actor(),
               "99999999999999999999",
               %{},
               @pagination
             ) ==
               {:error, :not_found}
    end
  end

  describe "put_erase_source_change/2" do
    test "deletes an added source change and removes its source from the image" do
      source = "https://spam.example/artwork"
      image = image_fixture(sources: [source])
      source_change = source_change_fixture(image, source_url: source, added: true)
      admin = admin_user_fixture()

      assert {:ok, %SourceChange{} = deleted_source_change} =
               SourceChanges.erase_source_change(actor(admin), source_change.id)

      assert deleted_source_change.id == source_change.id
      assert Repo.reload!(image) |> Repo.preload(:sources) |> Map.fetch!(:sources) == []
      refute Repo.get(SourceChange, source_change.id)
    end

    test "deletes a removed source change and restores its source to the image" do
      source = "https://spam.example/artwork"
      image = image_fixture()
      source_change = source_change_fixture(image, source_url: source, added: false)
      admin = admin_user_fixture()

      assert {:ok, %SourceChange{} = deleted_source_change} =
               SourceChanges.erase_source_change(actor(admin), source_change.id)

      assert deleted_source_change.id == source_change.id

      [restored_source] = Repo.reload!(image) |> Repo.preload(:sources) |> Map.fetch!(:sources)
      assert restored_source.source == source

      refute Repo.get(SourceChange, source_change.id)
    end
  end

  describe "list_user_source_changes/4" do
    test "a moderator lists a user's source changes newest-first" do
      user = confirmed_user_fixture()
      image = image_fixture()
      older = source_change_fixture(image, user_id: user.id)
      newer = source_change_fixture(image, user_id: user.id)

      assert {:ok,
              %SourceChangePage{
                target: loaded_user,
                source_changes: %Page{} = page,
                image_count: image_count
              }, _} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{},
                 @pagination
               )

      assert loaded_user.id == user.id
      assert Enum.map(page.entries, & &1.id) == [newer.id, older.id]
      assert image_count == 1
    end

    test "excludes changes to the user's own anonymous uploads" do
      user = confirmed_user_fixture()
      anon_image = image_fixture(%{user_id: user.id, anonymous: true})
      public_image = image_fixture()
      source_change_fixture(anon_image, user_id: user.id)
      kept = source_change_fixture(public_image, user_id: user.id)

      assert {:ok, %SourceChangePage{source_changes: page, image_count: image_count}, _} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [kept.id]
      assert image_count == 1
    end

    test "the added filter narrows to additions" do
      user = confirmed_user_fixture()
      image = image_fixture()
      removed_image = image_fixture()
      added = source_change_fixture(image, user_id: user.id, added: true)
      source_change_fixture(removed_image, user_id: user.id, added: false)

      assert {:ok, %SourceChangePage{source_changes: page, image_count: image_count}, _} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{"added" => "1"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [added.id]
      assert page.total_entries == 1
      assert image_count == 1
    end

    test "the added filter narrows to removals" do
      user = confirmed_user_fixture()
      image = image_fixture()
      source_change_fixture(image, user_id: user.id, added: true)
      removed = source_change_fixture(image, user_id: user.id, added: false)

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{"added" => "0"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [removed.id]
    end

    test "image_count reports the number of distinct images touched" do
      user = confirmed_user_fixture()
      image = image_fixture()
      other = image_fixture()
      source_change_fixture(image, user_id: user.id)
      source_change_fixture(image, user_id: user.id)
      source_change_fixture(other, user_id: user.id)

      assert {:ok, %SourceChangePage{image_count: image_count}, _} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{},
                 @pagination
               )

      assert image_count == 2
    end

    test "page_size caps the entries and reports the total" do
      user = confirmed_user_fixture()
      image = image_fixture()
      for _ <- 1..3, do: source_change_fixture(image, user_id: user.id)

      assert {:ok, %SourceChangePage{source_changes: page, image_count: image_count}, _} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{},
                 page: 1,
                 page_size: 2
               )

      assert page.page_size == 2
      assert length(page.entries) == 2
      assert page.total_entries == 3
      assert image_count == 1
    end

    test "a real profile is always allowed" do
      user = confirmed_user_fixture()

      assert {:ok, _page, _changeset} =
               SourceChanges.list_user_source_changes(actor(), user.slug, %{}, @pagination)

      assert {:ok, _page, _changeset} =
               SourceChanges.list_user_source_changes(
                 actor(confirmed_user_fixture()),
                 user.slug,
                 %{},
                 @pagination
               )
    end

    test "an unknown slug is not found for every actor" do
      assert SourceChanges.list_user_source_changes(actor(), "no-such-user", %{}, @pagination) ==
               {:error, :not_found}

      assert SourceChanges.list_user_source_changes(
               actor(admin_user_fixture()),
               "no-such-user",
               %{},
               @pagination
             ) == {:error, :not_found}
    end

    test "a deactivated profile is not found for non-staff and loads for staff" do
      user = deactivated_user_fixture()

      assert SourceChanges.list_user_source_changes(
               actor(confirmed_user_fixture()),
               user.slug,
               %{},
               @pagination
             ) == {:error, :not_found}

      assert {:ok, %SourceChangePage{target: loaded_user}, _changeset} =
               SourceChanges.list_user_source_changes(
                 actor(moderator_user_fixture()),
                 user.slug,
                 %{},
                 @pagination
               )

      assert loaded_user.id == user.id
    end
  end

  describe "count_for_image/1" do
    test "returns the number of source changes for the image" do
      image = image_fixture()
      source_change_fixture(image)
      source_change_fixture(image)

      assert SourceChanges.count_for_image(image) == 2
    end

    test "counts only the given image's changes" do
      image = image_fixture()
      other = image_fixture()
      source_change_fixture(image)
      source_change_fixture(other)

      assert SourceChanges.count_for_image(image) == 1
    end

    test "returns zero when the image has no source changes" do
      image = image_fixture()

      assert SourceChanges.count_for_image(image) == 0
    end
  end

  describe "list_ip_source_changes/4" do
    test "a moderator lists the changes attributed to an address, newest first" do
      image = image_fixture()
      older = source_change_fixture(image, ip: "203.0.113.5")
      newer = source_change_fixture(image, ip: "203.0.113.5")

      assert {:ok,
              %SourceChangePage{
                target: %Postgrex.INET{} = ip,
                range: %Postgrex.INET{} = range,
                source_changes: page
              }, _} =
               SourceChanges.list_ip_source_changes(
                 actor(moderator_user_fixture()),
                 "203.0.113.5",
                 %{},
                 @pagination
               )

      assert ip == range
      assert Enum.map(page.entries, & &1.id) == [newer.id, older.id]
    end

    test "the mask param widens the query to a subnet" do
      image = image_fixture()
      change = source_change_fixture(image, ip: "203.0.113.5")

      assert {:ok, %SourceChangePage{range: range, source_changes: page}, _} =
               SourceChanges.list_ip_source_changes(
                 actor(admin_user_fixture()),
                 "203.0.113.5",
                 %{"mask" => "24"},
                 @pagination
               )

      assert range.netmask == 24
      assert change.id in Enum.map(page.entries, & &1.id)
    end

    test "the added filter narrows to additions" do
      image = image_fixture()
      added = source_change_fixture(image, ip: "203.0.113.6", added: true)
      source_change_fixture(image, ip: "203.0.113.6", added: false)

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_ip_source_changes(
                 actor(moderator_user_fixture()),
                 "203.0.113.6",
                 %{"added" => "1"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [added.id]
    end

    test "a staffer submitting an unparsable address is not-found" do
      assert SourceChanges.list_ip_source_changes(
               actor(moderator_user_fixture()),
               "not-an-ip",
               %{},
               @pagination
             ) == {:error, :not_found}
    end

    test "a malformed address is not found before authorization" do
      assert SourceChanges.list_ip_source_changes(
               actor(confirmed_user_fixture()),
               "garbage",
               %{},
               @pagination
             ) == {:error, :not_found}
    end

    test "an anonymous viewer is unauthorized" do
      assert SourceChanges.list_ip_source_changes(actor(), "203.0.113.5", %{}, @pagination) ==
               {:error, :unauthorized}
    end
  end

  describe "list_fingerprint_source_changes/4" do
    test "a moderator lists the changes attributed to a fingerprint, newest first" do
      image = image_fixture()
      older = source_change_fixture(image, fingerprint: "c123")
      newer = source_change_fixture(image, fingerprint: "c123")

      assert {:ok, %SourceChangePage{target: "c123", source_changes: page}, _} =
               SourceChanges.list_fingerprint_source_changes(
                 actor(moderator_user_fixture()),
                 "c123",
                 %{},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [newer.id, older.id]
    end

    test "a valid fingerprint with no history returns an empty page" do
      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_fingerprint_source_changes(
                 actor(admin_user_fixture()),
                 "c999",
                 %{},
                 @pagination
               )

      assert page.entries == []
    end

    test "fingerprints are normalized before matching" do
      image = image_fixture()
      change = source_change_fixture(image, fingerprint: "d63c4581f8cf58d")

      assert {:ok, %SourceChangePage{target: "d63c4581f8cf58d", source_changes: page}, _} =
               SourceChanges.list_fingerprint_source_changes(
                 actor(moderator_user_fixture()),
                 " D63C4581F8CF58D ",
                 %{},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [change.id]
    end

    test "a malformed fingerprint is not found before authorization" do
      assert SourceChanges.list_fingerprint_source_changes(
               actor(),
               "no-such-fingerprint",
               %{},
               @pagination
             ) == {:error, :not_found}
    end

    test "the added filter narrows to removals" do
      image = image_fixture()
      source_change_fixture(image, fingerprint: "c456", added: true)
      removed = source_change_fixture(image, fingerprint: "c456", added: false)

      assert {:ok, %SourceChangePage{source_changes: page}, _} =
               SourceChanges.list_fingerprint_source_changes(
                 actor(moderator_user_fixture()),
                 "c456",
                 %{"added" => "0"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [removed.id]
    end

    test "a regular user is unauthorized" do
      assert SourceChanges.list_fingerprint_source_changes(
               actor(confirmed_user_fixture()),
               "c123",
               %{},
               @pagination
             ) == {:error, :unauthorized}
    end

    test "an anonymous viewer is unauthorized" do
      assert SourceChanges.list_fingerprint_source_changes(actor(), "c123", %{}, @pagination) ==
               {:error, :unauthorized}
    end
  end
end
