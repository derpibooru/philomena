defmodule Philomena.DonationsTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.Donations` functions:
  the admin index (`load_donations/2`), the per-user listing (`load_user_donations/2`),
  and `create_donation/2`.

  These pin the admin-only `:index, Donation` gate (moderators are rejected,
  since no moderator rule covers donations), the newest-first ordering with the
  user preloaded, the unknown-slug not-found shape, the foreign-key failure on a
  bad `user_id`, and the all-fields-optional insert.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.DonationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Donations
  alias Philomena.Donations.Donation

  @pagination [page: 1, page_size: 25]
  @ban %{reason: "Rule #0", valid_until: ~U[3000-01-01 00:00:00Z]}

  describe "list_donations/2" do
    test "an anonymous viewer is unauthorized" do
      assert Donations.list_donations(actor(), @pagination) == {:error, :unauthorized}
    end

    test "a regular user is unauthorized" do
      assert Donations.list_donations(actor(confirmed_user_fixture()), @pagination) ==
               {:error, :unauthorized}
    end

    test "a moderator is unauthorized" do
      assert Donations.list_donations(actor(moderator_user_fixture()), @pagination) ==
               {:error, :unauthorized}
    end

    test "an admin gets the paginated listing with the user preloaded" do
      user = confirmed_user_fixture()
      donation = donation_fixture(user)

      assert {:ok, page} = Donations.list_donations(actor(admin_user_fixture()), @pagination)

      loaded = Enum.find(page.entries, &(&1.id == donation.id))
      assert loaded
      refute match?(%Ecto.Association.NotLoaded{}, loaded.user)
      assert loaded.user.id == user.id
    end
  end

  describe "show_user_donations/2" do
    test "a regular user is unauthorized" do
      user = confirmed_user_fixture()

      assert Donations.show_user_donations(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "a moderator is unauthorized" do
      user = confirmed_user_fixture()

      assert Donations.show_user_donations(actor(moderator_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "an admin loads a user with their donations and an add-donation changeset" do
      user = confirmed_user_fixture()
      donation = donation_fixture(user)

      assert {:ok, {loaded, %Ecto.Changeset{data: %Donation{}}}} =
               Donations.show_user_donations(actor(admin_user_fixture()), user.slug)

      assert loaded.id == user.id
      assert donation.id in Enum.map(loaded.donations, & &1.id)
    end

    test "an unknown slug is not-found for an admin" do
      assert Donations.show_user_donations(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "create_donation/2" do
    test "an anonymous actor is unauthorized" do
      assert Donations.create_donation(actor(), %{"amount" => "5.00"}) == {:error, :unauthorized}
    end

    test "a regular user is unauthorized" do
      assert Donations.create_donation(actor(confirmed_user_fixture()), %{"amount" => "5.00"}) ==
               {:error, :unauthorized}
    end

    test "a moderator is unauthorized" do
      assert Donations.create_donation(actor(moderator_user_fixture()), %{"amount" => "5.00"}) ==
               {:error, :unauthorized}
    end

    test "an admin creates a donation attributed to a user" do
      user = confirmed_user_fixture()

      assert {:ok, %Donation{} = donation} =
               Donations.create_donation(actor(admin_user_fixture()), %{
                 "amount" => "10.00",
                 "email" => "donor@example.com",
                 "user_id" => user.id
               })

      assert donation.user_id == user.id
      assert Decimal.equal?(donation.amount, Decimal.new("10.00"))
    end

    test "an admin creates a donation from empty attrs, all fields being optional" do
      assert {:ok, %Donation{}} = Donations.create_donation(actor(admin_user_fixture()), %{})
    end

    test "a user_id naming no user is a foreign-key changeset error" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Donations.create_donation(actor(admin_user_fixture()), %{
                 "user_id" => 2_147_483_647
               })

      assert %{user_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "write access prerequisite" do
    test "the per-user form rejects bans but not missing fingerprints" do
      admin = admin_user_fixture()
      target = confirmed_user_fixture()

      assert Donations.show_user_donations(actor(admin, ban: @ban), target.slug) ==
               {:error, :ban}

      assert {:ok, _} = Donations.show_user_donations(actor(admin, fingerprint: nil), target.slug)
    end

    test "create rejects bans and missing fingerprints" do
      admin = admin_user_fixture()

      assert Donations.create_donation(actor(admin, ban: @ban), %{}) == {:error, :ban}

      assert Donations.create_donation(actor(admin, fingerprint: nil), %{}) ==
               {:error, :unauthorized}
    end
  end
end
