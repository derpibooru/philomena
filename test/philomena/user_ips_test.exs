defmodule Philomena.UserIpsTest do
  @moduledoc """
  Context-level tests for IP profiles and the actor-scoped user-history services
  consumed by Profiles.

  These pin parse-before-authorization error precedence, IPv4/IPv6
  canonicalization, the staff-only sensitive-identity gate, typed profile shape,
  pagination, and latest-row lookup.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.BansFixtures
  import Philomena.UserIpsFixtures
  import Philomena.UsersFixtures

  alias Philomena.UserIps
  alias Philomena.UserIps.IpProfile

  describe "show_ip_profile/2" do
    test "a moderator gets the users seen on the address and the covering subnet bans" do
      user = confirmed_user_fixture()
      user_ip_fixture(user, "203.0.113.50")
      subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

      assert {:ok, %IpProfile{ip: ip, user_ips: user_ips, subnet_bans: subnet_bans}} =
               UserIps.show_ip_profile(actor(moderator_user_fixture()), "203.0.113.50")

      assert %Postgrex.INET{} = ip
      assert user.id in Enum.map(user_ips, & &1.user.id)
      refute subnet_bans == []
    end

    test "an admin may load an IP profile" do
      assert {:ok, %IpProfile{}} =
               UserIps.show_ip_profile(actor(admin_user_fixture()), "203.0.113.1")
    end

    test "a staffer submitting an unparsable address is not-found" do
      assert UserIps.show_ip_profile(actor(moderator_user_fixture()), "not-an-ip") ==
               {:error, :not_found}
    end

    test "a valid unmatched address returns an empty typed profile" do
      assert {:ok, %IpProfile{user_ips: [], subnet_bans: []}} =
               UserIps.show_ip_profile(actor(moderator_user_fixture()), "198.51.100.42")
    end

    test "an equivalent IPv6 spelling is canonicalized" do
      assert {:ok, %IpProfile{ip: %Postgrex.INET{address: address}}} =
               UserIps.show_ip_profile(
                 actor(moderator_user_fixture()),
                 "2001:0DB8:0:0:0:0:0:1"
               )

      assert address == {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1}
    end

    test "a regular user is unauthorized, even for a valid address" do
      assert UserIps.show_ip_profile(actor(confirmed_user_fixture()), "203.0.113.1") ==
               {:error, :unauthorized}
    end

    test "an unprivileged viewer passing garbage is not-found" do
      assert UserIps.show_ip_profile(actor(confirmed_user_fixture()), "garbage") ==
               {:error, :not_found}
    end

    test "an anonymous viewer is unauthorized" do
      assert UserIps.show_ip_profile(actor(), "203.0.113.1") == {:error, :unauthorized}
    end
  end

  describe "profile history services" do
    test "loads a bounded page and latest row for an authorized actor" do
      subject = confirmed_user_fixture()
      other = confirmed_user_fixture()
      latest = user_ip_fixture(subject, "203.0.113.60")
      user_ip_fixture(other, "203.0.113.60")
      moderator = actor(moderator_user_fixture())

      assert {:ok, {page, other_users}} =
               UserIps.load_user_history(moderator, subject, page: 1, page_size: 1)

      assert Enum.map(page.entries, & &1.id) == [latest.id]
      assert other.id in Enum.map(other_users[latest.ip], & &1.user_id)
      assert UserIps.latest_for_user(moderator, subject) == {:ok, latest}
    end

    test "rejects an actor without the identity-metadata permission" do
      user = confirmed_user_fixture()
      actor = actor(confirmed_user_fixture())

      assert UserIps.load_user_history(actor, user, page: 1, page_size: 25) ==
               {:error, :unauthorized}

      assert UserIps.latest_for_user(actor, user) == {:error, :unauthorized}
    end
  end
end
