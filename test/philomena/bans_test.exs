defmodule Philomena.BansTest do
  @moduledoc """
  Context-level tests for `Philomena.Bans`.

  Two groups. The profile-page lookups (`subnet_bans_for_ip/1`,
  `fingerprint_bans_for/1`) pin subnet-containment, exact fingerprint match,
  newest-first ordering, and the empty result for an uncovered value.

  The admin ban management functions (index/new/create/edit/update/delete for
  user, subnet, and fingerprint bans) pin the per-role authorization matrix, the
  non-castable/unknown-id split, the admin-only restriction on deletes, the
  invalid-ip shapes on the subnet index and new form, and the byte-exact
  moderation-log type/subject_path/body written on each successful write.

  The actor here is a `Philomena.Attribution.Actor`, matching what the
  controller hands in as `conn.assigns.actor`.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.BansFixtures
  import Philomena.UserIpsFixtures, only: [inet: 1, user_ip_fixture: 2]
  import Philomena.UsersFixtures

  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Bans

  @pagination %{page_number: 1, page_size: 25}

  defp only_moderation_log!, do: Repo.one!(ModerationLog)

  defp moderation_log_count, do: Repo.aggregate(ModerationLog, :count)

  describe "subnet_bans_for_ip/1" do
    test "returns a subnet ban whose specification contains the address" do
      ban = subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

      assert ban.id in Enum.map(Bans.subnet_bans_for_ip(inet("203.0.113.50")), & &1.id)
    end

    test "excludes a subnet ban that does not contain the address" do
      subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

      assert Bans.subnet_bans_for_ip(inet("198.51.100.1")) == []
    end

    test "orders matching bans newest first" do
      older = subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})
      newer = subnet_ban_fixture(%{"specification" => "203.0.113.0/25"})

      set_created_at(Bans.Subnet, older.id, ~U[2020-01-01 00:00:00Z])
      set_created_at(Bans.Subnet, newer.id, ~U[2024-01-01 00:00:00Z])

      ids = Enum.map(Bans.subnet_bans_for_ip(inet("203.0.113.50")), & &1.id)
      assert Enum.find_index(ids, &(&1 == newer.id)) < Enum.find_index(ids, &(&1 == older.id))
    end
  end

  describe "fingerprint_bans_for/1" do
    test "returns a fingerprint ban matching the fingerprint" do
      ban = fingerprint_ban_fixture(%{"fingerprint" => "c0ffee1234"})

      assert ban.id in Enum.map(Bans.fingerprint_bans_for("c0ffee1234"), & &1.id)
    end

    test "excludes a ban for a different fingerprint" do
      fingerprint_ban_fixture(%{"fingerprint" => "c0ffee1234"})

      assert Bans.fingerprint_bans_for("deadbeef") == []
    end

    test "orders matching bans newest first" do
      older = fingerprint_ban_fixture(%{"fingerprint" => "abc123"})
      newer = fingerprint_ban_fixture(%{"fingerprint" => "abc123"})

      set_created_at(Bans.Fingerprint, older.id, ~U[2020-01-01 00:00:00Z])
      set_created_at(Bans.Fingerprint, newer.id, ~U[2024-01-01 00:00:00Z])

      ids = Enum.map(Bans.fingerprint_bans_for("abc123"), & &1.id)
      assert ids == [newer.id, older.id]
    end
  end

  describe "list_user_bans/3" do
    test "a moderator gets the paginated user bans" do
      moderator = moderator_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, page, _changeset} = Bans.list_user_bans(actor(moderator), %{}, @pagination)
      assert %Scrivener.Page{} = page
      assert ban.id in Enum.map(page.entries, & &1.id)
    end

    test "an admin gets the paginated user bans" do
      admin = admin_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, page, _changeset} = Bans.list_user_bans(actor(admin), %{}, @pagination)
      assert ban.id in Enum.map(page.entries, & &1.id)
    end

    test "a regular user is not authorized" do
      assert Bans.list_user_bans(actor(confirmed_user_fixture()), %{}, @pagination) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.list_user_bans(actor(), %{}, @pagination) == {:error, :unauthorized}
    end

    test "the bq branch matches a ban by its generated ban id" do
      moderator = moderator_user_fixture()
      ban = user_ban_fixture()
      _other = user_ban_fixture()

      assert {:ok, page, _changeset} =
               Bans.list_user_bans(
                 actor(moderator),
                 %{"bq" => ban.generated_ban_id},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [ban.id]
    end

    test "the bq branch matches a ban by the banned user's name" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture(%{name: "bantargetname"})
      ban = user_ban_fixture(target)

      assert {:ok, page, _changeset} =
               Bans.list_user_bans(actor(moderator), %{"bq" => "bantargetname"}, @pagination)

      assert ban.id in Enum.map(page.entries, & &1.id)
    end

    test "the user_id branch filters to that user's bans" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      ban = user_ban_fixture(target)
      _other = user_ban_fixture()

      assert {:ok, page, _changeset} =
               Bans.list_user_bans(actor(moderator), %{"user_id" => "#{target.id}"}, @pagination)

      assert Enum.map(page.entries, & &1.id) == [ban.id]
    end

    test "a non-integer user_id filter returns a changeset error" do
      moderator = moderator_user_fixture()

      assert {:error, changeset} =
               Bans.list_user_bans(actor(moderator), %{"user_id" => "abc"}, @pagination)

      assert {"is invalid", _opts} = changeset.errors[:user_id]
    end
  end

  describe "new_user_ban/2" do
    test "a moderator gets the target and a changeset for a known user id" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               Bans.new_user_ban(actor(moderator), "#{target.id}")

      assert loaded.id == target.id
    end

    test "an unknown but castable user id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.new_user_ban(actor(moderator), "2147483647") == {:error, :not_found}
    end

    test "a non-castable user id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.new_user_ban(actor(moderator), "abc") == {:error, :not_found}
    end

    test "a nil user id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.new_user_ban(actor(moderator), nil) == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      target = confirmed_user_fixture()

      assert Bans.new_user_ban(actor(confirmed_user_fixture()), "#{target.id}") ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      target = confirmed_user_fixture()
      assert Bans.new_user_ban(actor(), "#{target.id}") == {:error, :unauthorized}
    end
  end

  describe "create_user_ban/2" do
    test "a moderator creates a ban and a moderation log is written" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert {:ok, ban} =
               Bans.create_user_ban(actor(moderator), target.id, valid_user_ban_attrs())

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Admin.UserBan:create"
      assert log.subject_path == "/admin/user_bans"
      assert log.body == "Created a user ban #{ban.generated_ban_id}"
    end

    test "an admin creates a ban" do
      admin = admin_user_fixture()
      target = confirmed_user_fixture()

      assert {:ok, _ban} = Bans.create_user_ban(actor(admin), target.id, valid_user_ban_attrs())
    end

    test "creation automatically bans the target's latest IPv6 /64" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      user_ip_fixture(target, "2001:db8:1:2:3:4:5:6")

      assert {:ok, _ban} =
               Bans.create_user_ban(actor(moderator), target.id, valid_user_ban_attrs())

      assert %Bans.Subnet{
               specification: %Postgrex.INET{
                 address: {0x2001, 0xDB8, 1, 2, 0, 0, 0, 0},
                 netmask: 64
               }
             } = Repo.one!(Bans.Subnet)
    end

    test "creation automatically bans the target's latest IPv4 address unchanged" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      user_ip_fixture(target, "203.0.113.51")

      assert {:ok, _ban} =
               Bans.create_user_ban(actor(moderator), target.id, valid_user_ban_attrs())

      assert %Bans.Subnet{
               specification: %Postgrex.INET{address: {203, 0, 113, 51}, netmask: 32}
             } = Repo.one!(Bans.Subnet)
    end

    test "invalid attributes return a changeset and write no log" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bans.create_user_ban(actor(moderator), target.id, %{
                 valid_user_ban_attrs()
                 | "reason" => ""
               })

      assert moderation_log_count() == 0
    end

    test "a regular user is not authorized and creates nothing" do
      target = confirmed_user_fixture()

      assert Bans.create_user_ban(
               actor(confirmed_user_fixture()),
               target.id,
               valid_user_ban_attrs()
             ) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "an anonymous visitor is not authorized" do
      target = confirmed_user_fixture()

      assert Bans.create_user_ban(actor(), target.id, valid_user_ban_attrs()) ==
               {:error, :unauthorized}
    end
  end

  describe "edit_user_ban/2" do
    test "a moderator loads the ban with the banned user preloaded" do
      moderator = moderator_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               Bans.edit_user_ban(actor(moderator), ban.id)

      assert loaded.id == ban.id
      refute match?(%Ecto.Association.NotLoaded{}, loaded.user)
    end

    test "an admin loads the ban" do
      admin = admin_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, {loaded, _}} = Bans.edit_user_ban(actor(admin), ban.id)
      assert loaded.id == ban.id
    end

    test "an unknown id is not found for a moderator" do
      moderator = moderator_user_fixture()
      assert Bans.edit_user_ban(actor(moderator), 2_147_483_647) == {:error, :not_found}
    end

    test "an unknown id is not found for an admin" do
      admin = admin_user_fixture()
      assert Bans.edit_user_ban(actor(admin), 2_147_483_647) == {:error, :not_found}
    end

    test "a non-castable id is not found for a moderator" do
      moderator = moderator_user_fixture()
      assert Bans.edit_user_ban(actor(moderator), "abc") == {:error, :not_found}
    end

    test "a non-castable id is not found for an admin" do
      admin = admin_user_fixture()
      assert Bans.edit_user_ban(actor(admin), "abc") == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = user_ban_fixture()

      assert Bans.edit_user_ban(actor(confirmed_user_fixture()), ban.id) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      ban = user_ban_fixture()
      assert Bans.edit_user_ban(actor(), ban.id) == {:error, :unauthorized}
    end
  end

  describe "update_user_ban/3" do
    test "a moderator updates the ban and a moderation log is written" do
      moderator = moderator_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, updated} =
               Bans.update_user_ban(actor(moderator), ban.id, %{"reason" => "Changed"})

      assert updated.reason == "Changed"

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Admin.UserBan:update"
      assert log.subject_path == "/admin/user_bans"
      assert log.body == "Updated a user ban #{ban.generated_ban_id}"
    end

    test "an admin updates the ban" do
      admin = admin_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, _} = Bans.update_user_ban(actor(admin), ban.id, %{"reason" => "Changed"})
    end

    test "invalid attributes return a changeset and write no log" do
      moderator = moderator_user_fixture()
      ban = user_ban_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bans.update_user_ban(actor(moderator), ban.id, %{"reason" => ""})

      assert moderation_log_count() == 0
    end

    test "an unknown id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.update_user_ban(actor(moderator), 2_147_483_647, %{"reason" => "x"}) ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.update_user_ban(actor(moderator), "abc", %{"reason" => "x"}) ==
               {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = user_ban_fixture()

      assert Bans.update_user_ban(actor(confirmed_user_fixture()), ban.id, %{"reason" => "x"}) ==
               {:error, :unauthorized}
    end
  end

  describe "delete_user_ban/2" do
    test "an admin deletes the ban and a moderation log is written" do
      admin = admin_user_fixture()
      ban = user_ban_fixture()

      assert {:ok, deleted} = Bans.delete_user_ban(actor(admin), ban.id)
      assert deleted.id == ban.id
      refute Repo.get(Bans.User, ban.id)

      log = only_moderation_log!()
      assert log.user_id == admin.id
      assert log.type == "Admin.UserBan:delete"
      assert log.subject_path == "/admin/user_bans"
      assert log.body == "Deleted a user ban #{ban.generated_ban_id}"
    end

    test "a moderator with a real ban id is not authorized to delete" do
      # Deleting is admin-only; a moderator passes the module-level authorize and
      # loads the ban, then fails the admin-only delete check.
      moderator = moderator_user_fixture()
      ban = user_ban_fixture()

      assert Bans.delete_user_ban(actor(moderator), ban.id) == {:error, :unauthorized}
      assert Repo.get(Bans.User, ban.id)
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown id is not found, not unauthorized" do
      # The load runs before the admin-only delete check, so a missing ban is
      # not_found even for a moderator who could never delete it.
      moderator = moderator_user_fixture()
      assert Bans.delete_user_ban(actor(moderator), 2_147_483_647) == {:error, :not_found}
    end

    test "an admin with an unknown id is not found" do
      admin = admin_user_fixture()
      assert Bans.delete_user_ban(actor(admin), 2_147_483_647) == {:error, :not_found}
    end

    test "a non-castable id is not found for a moderator" do
      moderator = moderator_user_fixture()
      assert Bans.delete_user_ban(actor(moderator), "abc") == {:error, :not_found}
    end

    test "a non-castable id is not found for an admin" do
      admin = admin_user_fixture()
      assert Bans.delete_user_ban(actor(admin), "abc") == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = user_ban_fixture()

      assert Bans.delete_user_ban(actor(confirmed_user_fixture()), ban.id) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      ban = user_ban_fixture()
      assert Bans.delete_user_ban(actor(), ban.id) == {:error, :unauthorized}
    end
  end

  describe "list_subnet_bans/3" do
    test "a moderator gets the paginated subnet bans" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture()

      assert {:ok, page, _changeset} = Bans.list_subnet_bans(actor(moderator), %{}, @pagination)
      assert ban.id in Enum.map(page.entries, & &1.id)
    end

    test "the bq branch matches a ban by its generated ban id" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture()
      _other = subnet_ban_fixture()

      assert {:ok, page, _changeset} =
               Bans.list_subnet_bans(
                 actor(moderator),
                 %{"bq" => ban.generated_ban_id},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [ban.id]
    end

    test "the ip branch matches a subnet ban containing the address" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

      assert {:ok, page, _changeset} =
               Bans.list_subnet_bans(actor(moderator), %{"ip" => "203.0.113.50"}, @pagination)

      assert ban.id in Enum.map(page.entries, & &1.id)
    end

    test "an invalid ip in the ip branch returns a changeset error" do
      moderator = moderator_user_fixture()

      assert {:error, changeset} =
               Bans.list_subnet_bans(actor(moderator), %{"ip" => "not-an-ip"}, @pagination)

      assert {"is invalid", _opts} = changeset.errors[:ip]
    end

    test "a regular user is not authorized" do
      assert Bans.list_subnet_bans(actor(confirmed_user_fixture()), %{}, @pagination) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.list_subnet_bans(actor(), %{}, @pagination) == {:error, :unauthorized}
    end
  end

  describe "new_subnet_ban/2" do
    test "a moderator gets a blank changeset for a nil specification" do
      moderator = moderator_user_fixture()

      assert {:ok, %Ecto.Changeset{} = changeset} = Bans.new_subnet_ban(actor(moderator), nil)
      assert Ecto.Changeset.get_field(changeset, :specification) == nil
    end

    test "a moderator gets a changeset prefilled with a valid specification" do
      moderator = moderator_user_fixture()

      assert {:ok, %Ecto.Changeset{} = changeset} =
               Bans.new_subnet_ban(actor(moderator), "203.0.113.0/24")

      refute is_nil(Ecto.Changeset.get_field(changeset, :specification))
    end

    test "an invalid specification is returned in the changeset" do
      moderator = moderator_user_fixture()

      assert {:ok, changeset} = Bans.new_subnet_ban(actor(moderator), "not-an-ip")
      assert {"is invalid", _opts} = changeset.errors[:specification]
    end

    test "a regular user is not authorized even with an invalid specification" do
      # Authorization runs ahead of validation, so an unprivileged actor gets
      # the unauthorized error rather than a changeset.
      assert Bans.new_subnet_ban(actor(confirmed_user_fixture()), "not-an-ip") ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.new_subnet_ban(actor(), "203.0.113.0/24") == {:error, :unauthorized}
    end
  end

  describe "create_subnet_ban/2" do
    test "a moderator creates a ban and a moderation log is written" do
      moderator = moderator_user_fixture()

      assert {:ok, ban} = Bans.create_subnet_ban(actor(moderator), valid_subnet_ban_attrs())

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Admin.SubnetBan:create"
      assert log.subject_path == "/admin/subnet_bans"
      assert log.body == "Created a subnet ban #{ban.generated_ban_id}"
    end

    test "invalid attributes return a changeset and write no log" do
      moderator = moderator_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bans.create_subnet_ban(actor(moderator), %{
                 valid_subnet_ban_attrs()
                 | "reason" => ""
               })

      assert moderation_log_count() == 0
    end

    test "a regular user is not authorized and creates nothing" do
      assert Bans.create_subnet_ban(actor(confirmed_user_fixture()), valid_subnet_ban_attrs()) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.create_subnet_ban(actor(), valid_subnet_ban_attrs()) == {:error, :unauthorized}
    end
  end

  describe "edit_subnet_ban/2" do
    test "a moderator loads the ban" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               Bans.edit_subnet_ban(actor(moderator), ban.id)

      assert loaded.id == ban.id
    end

    test "an unknown id is not found for a moderator" do
      moderator = moderator_user_fixture()

      assert Bans.edit_subnet_ban(actor(moderator), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "an unknown id is not found for an admin" do
      admin = admin_user_fixture()
      assert Bans.edit_subnet_ban(actor(admin), 2_147_483_647) == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()
      assert Bans.edit_subnet_ban(actor(moderator), "abc") == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = subnet_ban_fixture()

      assert Bans.edit_subnet_ban(actor(confirmed_user_fixture()), ban.id) ==
               {:error, :unauthorized}
    end
  end

  describe "update_subnet_ban/3" do
    test "a moderator updates the ban and a moderation log is written" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture()

      assert {:ok, updated} =
               Bans.update_subnet_ban(actor(moderator), ban.id, %{"reason" => "Changed"})

      assert updated.reason == "Changed"

      log = only_moderation_log!()
      assert log.type == "Admin.SubnetBan:update"
      assert log.subject_path == "/admin/subnet_bans"
      assert log.body == "Updated a subnet ban #{ban.generated_ban_id}"
    end

    test "invalid attributes return a changeset and write no log" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bans.update_subnet_ban(actor(moderator), ban.id, %{"reason" => ""})

      assert moderation_log_count() == 0
    end

    test "an unknown id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.update_subnet_ban(actor(moderator), 2_147_483_647, %{"reason" => "x"}) ==
               {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = subnet_ban_fixture()

      assert Bans.update_subnet_ban(actor(confirmed_user_fixture()), ban.id, %{"reason" => "x"}) ==
               {:error, :unauthorized}
    end
  end

  describe "delete_subnet_ban/2" do
    test "an admin deletes the ban and a moderation log is written" do
      admin = admin_user_fixture()
      ban = subnet_ban_fixture()

      assert {:ok, deleted} = Bans.delete_subnet_ban(actor(admin), ban.id)
      assert deleted.id == ban.id
      refute Repo.get(Bans.Subnet, ban.id)

      log = only_moderation_log!()
      assert log.type == "Admin.SubnetBan:delete"
      assert log.subject_path == "/admin/subnet_bans"
      assert log.body == "Deleted a subnet ban #{ban.generated_ban_id}"
    end

    test "a moderator with a real ban id is not authorized to delete" do
      moderator = moderator_user_fixture()
      ban = subnet_ban_fixture()

      assert Bans.delete_subnet_ban(actor(moderator), ban.id) == {:error, :unauthorized}
      assert Repo.get(Bans.Subnet, ban.id)
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown id is not found" do
      moderator = moderator_user_fixture()
      assert Bans.delete_subnet_ban(actor(moderator), 2_147_483_647) == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      admin = admin_user_fixture()
      assert Bans.delete_subnet_ban(actor(admin), "abc") == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = subnet_ban_fixture()

      assert Bans.delete_subnet_ban(actor(confirmed_user_fixture()), ban.id) ==
               {:error, :unauthorized}
    end
  end

  describe "list_fingerprint_bans/3" do
    test "a moderator gets the paginated fingerprint bans" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture()

      assert {:ok, page, _changeset} =
               Bans.list_fingerprint_bans(actor(moderator), %{}, @pagination)

      assert ban.id in Enum.map(page.entries, & &1.id)
    end

    test "the bq branch matches a ban by its generated ban id" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture()
      _other = fingerprint_ban_fixture()

      assert {:ok, page, _changeset} =
               Bans.list_fingerprint_bans(
                 actor(moderator),
                 %{"bq" => ban.generated_ban_id},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [ban.id]
    end

    test "the fingerprint branch filters to an exact fingerprint" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture(%{"fingerprint" => "c0ffee1234"})
      _other = fingerprint_ban_fixture(%{"fingerprint" => "deadbeef"})

      assert {:ok, page, _changeset} =
               Bans.list_fingerprint_bans(
                 actor(moderator),
                 %{"fingerprint" => "c0ffee1234"},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [ban.id]
    end

    test "a regular user is not authorized" do
      assert Bans.list_fingerprint_bans(actor(confirmed_user_fixture()), %{}, @pagination) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.list_fingerprint_bans(actor(), %{}, @pagination) == {:error, :unauthorized}
    end
  end

  describe "new_fingerprint_ban/2" do
    test "a moderator gets a changeset prefilled with the fingerprint" do
      moderator = moderator_user_fixture()

      assert {:ok, %Ecto.Changeset{} = changeset} =
               Bans.new_fingerprint_ban(actor(moderator), "c0ffee1234")

      assert Ecto.Changeset.get_field(changeset, :fingerprint) == "c0ffee1234"
    end

    test "a regular user is not authorized" do
      assert Bans.new_fingerprint_ban(actor(confirmed_user_fixture()), "c0ffee1234") ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.new_fingerprint_ban(actor(), "c0ffee1234") == {:error, :unauthorized}
    end
  end

  describe "create_fingerprint_ban/2" do
    test "a moderator creates a ban and a moderation log is written" do
      moderator = moderator_user_fixture()

      assert {:ok, ban} =
               Bans.create_fingerprint_ban(actor(moderator), valid_fingerprint_ban_attrs())

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Admin.FingerprintBan:create"
      assert log.subject_path == "/admin/fingerprint_bans"
      assert log.body == "Created a fingerprint ban #{ban.generated_ban_id}"
    end

    test "invalid attributes return a changeset and write no log" do
      moderator = moderator_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bans.create_fingerprint_ban(actor(moderator), %{
                 valid_fingerprint_ban_attrs()
                 | "reason" => ""
               })

      assert moderation_log_count() == 0
    end

    test "a regular user is not authorized" do
      assert Bans.create_fingerprint_ban(
               actor(confirmed_user_fixture()),
               valid_fingerprint_ban_attrs()
             ) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Bans.create_fingerprint_ban(actor(), valid_fingerprint_ban_attrs()) ==
               {:error, :unauthorized}
    end
  end

  describe "edit_fingerprint_ban/2" do
    test "a moderator loads the ban" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               Bans.edit_fingerprint_ban(actor(moderator), ban.id)

      assert loaded.id == ban.id
    end

    test "an unknown id is not found for a moderator" do
      moderator = moderator_user_fixture()

      assert Bans.edit_fingerprint_ban(actor(moderator), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "an unknown id is not found for an admin" do
      admin = admin_user_fixture()

      assert Bans.edit_fingerprint_ban(actor(admin), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()
      assert Bans.edit_fingerprint_ban(actor(moderator), "abc") == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = fingerprint_ban_fixture()

      assert Bans.edit_fingerprint_ban(actor(confirmed_user_fixture()), ban.id) ==
               {:error, :unauthorized}
    end
  end

  describe "update_fingerprint_ban/3" do
    test "a moderator updates the ban and a moderation log is written" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture()

      assert {:ok, updated} =
               Bans.update_fingerprint_ban(actor(moderator), ban.id, %{"reason" => "Changed"})

      assert updated.reason == "Changed"

      log = only_moderation_log!()
      assert log.type == "Admin.FingerprintBan:update"
      assert log.subject_path == "/admin/fingerprint_bans"
      assert log.body == "Updated a fingerprint ban #{ban.generated_ban_id}"
    end

    test "invalid attributes return a changeset and write no log" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Bans.update_fingerprint_ban(actor(moderator), ban.id, %{"reason" => ""})

      assert moderation_log_count() == 0
    end

    test "an unknown id is not found" do
      moderator = moderator_user_fixture()

      assert Bans.update_fingerprint_ban(actor(moderator), 2_147_483_647, %{"reason" => "x"}) ==
               {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = fingerprint_ban_fixture()

      assert Bans.update_fingerprint_ban(actor(confirmed_user_fixture()), ban.id, %{
               "reason" => "x"
             }) ==
               {:error, :unauthorized}
    end
  end

  describe "delete_fingerprint_ban/2" do
    test "an admin deletes the ban and a moderation log is written" do
      admin = admin_user_fixture()
      ban = fingerprint_ban_fixture()

      assert {:ok, deleted} = Bans.delete_fingerprint_ban(actor(admin), ban.id)
      assert deleted.id == ban.id
      refute Repo.get(Bans.Fingerprint, ban.id)

      log = only_moderation_log!()
      assert log.type == "Admin.FingerprintBan:delete"
      assert log.subject_path == "/admin/fingerprint_bans"
      assert log.body == "Deleted a fingerprint ban #{ban.generated_ban_id}"
    end

    test "a moderator with a real ban id is not authorized to delete" do
      moderator = moderator_user_fixture()
      ban = fingerprint_ban_fixture()

      assert Bans.delete_fingerprint_ban(actor(moderator), ban.id) == {:error, :unauthorized}
      assert Repo.get(Bans.Fingerprint, ban.id)
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown id is not found" do
      moderator = moderator_user_fixture()
      assert Bans.delete_fingerprint_ban(actor(moderator), 2_147_483_647) == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      admin = admin_user_fixture()
      assert Bans.delete_fingerprint_ban(actor(admin), "abc") == {:error, :not_found}
    end

    test "a regular user is not authorized" do
      ban = fingerprint_ban_fixture()

      assert Bans.delete_fingerprint_ban(actor(confirmed_user_fixture()), ban.id) ==
               {:error, :unauthorized}
    end
  end

  describe "shared ban-management contracts" do
    test "a ban takes precedence over authorization for every ban creation flow" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      banned_actor = actor(moderator, ban: %{active: true})

      assert Bans.create_user_ban(banned_actor, target.id, valid_user_ban_attrs()) ==
               {:error, :ban}

      assert Bans.create_subnet_ban(banned_actor, valid_subnet_ban_attrs()) ==
               {:error, :ban}

      assert Bans.create_fingerprint_ban(banned_actor, valid_fingerprint_ban_attrs()) ==
               {:error, :ban}

      assert moderation_log_count() == 0
    end

    test "a missing fingerprint rejects every ban creation flow" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      unattributed_actor = actor(moderator, fingerprint: nil)

      assert Bans.create_user_ban(unattributed_actor, target.id, valid_user_ban_attrs()) ==
               {:error, :unauthorized}

      assert Bans.create_subnet_ban(unattributed_actor, valid_subnet_ban_attrs()) ==
               {:error, :unauthorized}

      assert Bans.create_fingerprint_ban(unattributed_actor, valid_fingerprint_ban_attrs()) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "malformed member IDs are not found before authorization for all ban kinds" do
      user_actor = actor(confirmed_user_fixture())

      assert Bans.edit_user_ban(user_actor, "bad-id") == {:error, :not_found}
      assert Bans.update_user_ban(user_actor, "bad-id", %{}) == {:error, :not_found}
      assert Bans.delete_user_ban(user_actor, "bad-id") == {:error, :not_found}

      assert Bans.edit_subnet_ban(user_actor, "bad-id") == {:error, :not_found}
      assert Bans.update_subnet_ban(user_actor, "bad-id", %{}) == {:error, :not_found}
      assert Bans.delete_subnet_ban(user_actor, "bad-id") == {:error, :not_found}

      assert Bans.edit_fingerprint_ban(user_actor, "bad-id") ==
               {:error, :not_found}

      assert Bans.update_fingerprint_ban(user_actor, "bad-id", %{}) ==
               {:error, :not_found}

      assert Bans.delete_fingerprint_ban(user_actor, "bad-id") == {:error, :not_found}
    end
  end

  describe "find/3" do
    test "an anonymous request prefers a subnet ban over a fingerprint ban" do
      fingerprint = "d015c342859dde3"
      _fingerprint_ban = fingerprint_ban_fixture(%{"fingerprint" => fingerprint})
      _subnet_ban = subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

      assert %{type: "Subnet"} = Bans.find(nil, inet("203.0.113.50"), fingerprint)
    end

    test "a signed-in request ignores matching subnet and fingerprint bans" do
      user = confirmed_user_fixture()
      fingerprint = "d015c342859dde3"
      _fingerprint_ban = fingerprint_ban_fixture(%{"fingerprint" => fingerprint})
      _subnet_ban = subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

      assert Bans.find(user, inet("203.0.113.50"), fingerprint) == nil
    end

    test "a signed-in request returns its user ban" do
      user = confirmed_user_fixture()
      _user_ban = user_ban_fixture(user)

      assert %{type: "User"} = Bans.find(user, inet("203.0.113.50"), "d015c342859dde3")
    end

    test "the newest matching ban wins within one ban kind" do
      fingerprint = "d015c342859dde3"
      older = fingerprint_ban_fixture(%{"fingerprint" => fingerprint, "reason" => "older"})
      newer = fingerprint_ban_fixture(%{"fingerprint" => fingerprint, "reason" => "newer"})

      set_created_at(Bans.Fingerprint, older.id, ~U[2020-01-01 00:00:00Z])
      set_created_at(Bans.Fingerprint, newer.id, ~U[2024-01-01 00:00:00Z])

      assert %{generated_ban_id: generated_ban_id} = Bans.find(nil, nil, fingerprint)
      assert generated_ban_id == newer.generated_ban_id
    end

    test "an identity with no attributes has no ban" do
      assert Bans.find(nil, nil, nil) == nil
    end
  end

  # Controller-shaped attrs (string keys) a user ban insert requires: a target,
  # a reason, and a valid_until (a RelativeDate a plain DateTime casts fine).
  defp valid_user_ban_attrs do
    %{
      "reason" => "Test ban reason",
      "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
    }
  end

  defp valid_subnet_ban_attrs do
    %{
      "specification" => "203.0.113.0/24",
      "reason" => "Test subnet reason",
      "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
    }
  end

  defp valid_fingerprint_ban_attrs do
    %{
      "fingerprint" => "d015c342859dde3",
      "reason" => "Test fingerprint reason",
      "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
    }
  end

  # Stamps created_at directly so the newest-first ordering can be observed
  # without relying on insertion timing.
  defp set_created_at(schema, id, created_at) do
    schema
    |> where(id: ^id)
    |> Repo.update_all(set: [created_at: created_at])
  end
end
