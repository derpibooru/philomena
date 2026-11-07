defmodule Philomena.CommissionsTest do
  @moduledoc """
  Context-level tests for the actor-first commission and commission-item loaders
  and writers on `Philomena.Commissions`.

  These pin typed page/form/directory results, stable profile and nested-item
  lookup errors, the staff bypass on commission management (and its absence on
  item management), verified-link and write-access gates, and persistence
  invariants.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ArtistLinksFixtures
  import Philomena.CommissionsFixtures
  import Philomena.TagsFixtures
  import Philomena.UserIpsFixtures
  import Philomena.UsersFixtures
  import Philomena.ReportsFixtures

  alias Philomena.Commissions
  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Directory
  alias Philomena.Commissions.Item
  alias Philomena.Repo
  alias Philomena.Reports.Report

  # A truthy ban value in the shape production passes; only its presence matters
  # to the write-access and not-banned checks the loaders run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  defp artist_tag_fixture do
    tag_fixture(name: "artist:test-commission-artist-#{System.unique_integer([:positive])}")
  end

  # A confirmed user holding a verified artist link, which the commission gates
  # require the profile to have.
  defp verified_user_with_link do
    user = confirmed_user_fixture()
    verified_artist_link_fixture(user, artist_tag_fixture())
    user
  end

  defp commission_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      "information" => "Test commission information",
      "contact" => "Test contact info",
      "will_create" => "Test subjects",
      "open" => true
    })
  end

  defp item_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      "item_type" => "Sketch",
      "description" => "Test item description",
      "base_price" => 20
    })
  end

  describe "show_commission/2" do
    test "returns an ordered commission page" do
      user = confirmed_user_fixture()
      commission = commission_fixture(user)
      expensive = commission_item_fixture(commission, base_price: 30)
      cheap = commission_item_fixture(commission, base_price: 10)

      assert {:ok, %Commission{} = loaded_commission} =
               Commissions.show_commission(actor(), user.slug)

      assert loaded_commission.user.id == user.id
      assert loaded_commission.id == commission.id
      assert Enum.map(loaded_commission.items, & &1.id) == [cheap.id, expensive.id]
    end

    test "a missing profile is not found and a deactivated one loads only for staff" do
      deactivated = confirmed_user_fixture()
      commission_fixture(deactivated)

      deactivated
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update!()

      for viewer <- [actor(), actor(confirmed_user_fixture())] do
        assert Commissions.show_commission(viewer, "no-such-user") ==
                 {:error, :not_found}

        assert Commissions.show_commission(viewer, deactivated.slug) ==
                 {:error, :not_found}
      end

      assert {:ok, %Commission{user: %{id: user_id}}} =
               Commissions.show_commission(actor(moderator_user_fixture()), deactivated.slug)

      assert user_id == deactivated.id
    end

    test "a user without a commission is not-found" do
      assert Commissions.show_commission(actor(), confirmed_user_fixture().slug) ==
               {:error, :not_found}
    end
  end

  describe "new_commission/2" do
    test "the owner with a verified link and no commission gets a form" do
      user = verified_user_with_link()

      assert {:ok, %Ecto.Changeset{data: commission}} =
               Commissions.new_commission(actor(user), user.slug)

      assert commission.user.id == user.id
    end

    test "a moderator may open the new form for another user (staff bypass)" do
      user = verified_user_with_link()

      assert {:ok, %Ecto.Changeset{data: commission}} =
               Commissions.new_commission(actor(moderator_user_fixture()), user.slug)

      assert commission.user.id == user.id
    end

    test "a banned actor is rejected before any gating" do
      user = verified_user_with_link()

      assert Commissions.new_commission(actor(user, ban: @ban), user.slug) ==
               {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      user = verified_user_with_link()

      assert {:ok, _} = Commissions.new_commission(actor(user, fingerprint: nil), user.slug)
    end

    test "an owner whose profile already has a commission is unauthorized" do
      user = verified_user_with_link()
      commission_fixture(user)

      assert Commissions.new_commission(actor(user), user.slug) ==
               {:error, :unauthorized}
    end

    test "an unrelated user may not open another owner's new form" do
      user = verified_user_with_link()

      assert Commissions.new_commission(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "an owner without a verified link gets the no-verified-links shape" do
      user = confirmed_user_fixture()

      assert Commissions.new_commission(actor(user), user.slug) ==
               {:error, :no_verified_links}
    end
  end

  describe "create_commission/3" do
    test "the owner creates a commission" do
      user = verified_user_with_link()

      assert {:ok, %Commission{} = commission} =
               Commissions.create_commission(actor(user), user.slug, commission_params())

      assert commission.user.id == user.id
      assert Repo.get(Commission, commission.id).user_id == user.id
      assert commission.items == []
    end

    test "the database enforces one commission per profile" do
      user = confirmed_user_fixture()
      new_commission = fn -> Ecto.build_assoc(user, :commission) end

      assert {:ok, %Commission{}} =
               new_commission.() |> Commission.changeset(commission_params()) |> Repo.insert()

      assert {:error, changeset} =
               new_commission.() |> Commission.changeset(commission_params()) |> Repo.insert()

      assert {"has already been taken", _} = changeset.errors[:user_id]
    end

    test "an actor with no fingerprint is unauthorized" do
      user = verified_user_with_link()

      assert Commissions.create_commission(
               actor(user, fingerprint: nil),
               user.slug,
               commission_params()
             ) == {:error, :unauthorized}
    end

    test "validation errors retain the scoped commission" do
      user = verified_user_with_link()

      assert {:error, %Ecto.Changeset{data: commission} = changeset} =
               Commissions.create_commission(actor(user), user.slug, %{})

      assert commission.user.id == user.id
      refute changeset.valid?
    end
  end

  describe "edit_commission/2" do
    test "the owner loads their commission and a changeset" do
      user = verified_user_with_link()
      commission = commission_fixture(user)

      assert {:ok, %Ecto.Changeset{data: loaded_commission}} =
               Commissions.edit_commission(actor(user), user.slug)

      assert loaded_commission.user.id == user.id
      assert loaded_commission.id == commission.id
    end

    test "a profile without a commission is not-found" do
      user = verified_user_with_link()

      assert Commissions.edit_commission(actor(user), user.slug) == {:error, :not_found}
    end

    test "an unrelated user may not edit another owner's commission" do
      user = verified_user_with_link()
      commission_fixture(user)

      assert Commissions.edit_commission(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "an actor without a fingerprint still gets the form" do
      user = verified_user_with_link()
      commission_fixture(user)

      assert {:ok, _} = Commissions.edit_commission(actor(user, fingerprint: nil), user.slug)
    end
  end

  describe "update_commission/3" do
    test "the owner updates their commission" do
      user = verified_user_with_link()
      commission = commission_fixture(user)

      assert {:ok, %Commission{} = updated} =
               Commissions.update_commission(
                 actor(user),
                 user.slug,
                 commission_params(%{"information" => "Updated information"})
               )

      assert updated.id == commission.id
      assert Repo.get(Commission, commission.id).information == "Updated information"
    end

    test "a sheet image id naming no image is a changeset error" do
      user = verified_user_with_link()
      commission_fixture(user)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Commissions.update_commission(
                 actor(user),
                 user.slug,
                 commission_params(%{"sheet_image_id" => "999999999"})
               )

      assert {"does not exist", _} = changeset.errors[:sheet_image_id]
    end
  end

  describe "delete_commission/2" do
    test "the owner deletes their commission" do
      user = verified_user_with_link()
      commission = commission_fixture(user)

      assert {:ok, %Commission{}} = Commissions.delete_commission(actor(user), user.slug)
      assert Repo.get(Commission, commission.id) == nil
    end
  end

  describe "delete_commission/2 report cleanup" do
    test "closes the commission's open reports and nulls the target FK while keeping the row" do
      owner = verified_user_with_link()
      commission = commission_fixture(owner)
      report = report_fixture(commission_id: commission.id)
      admin = admin_user_fixture()

      assert report.open
      assert report.commission_id == commission.id

      assert {:ok, _commission} = Commissions.delete_commission(actor(admin), owner.slug)

      closed = Repo.get!(Report, report.id)
      refute closed.open
      assert closed.state == "closed"
      assert closed.admin_id == admin.id
      # The FK is nilified by the database, orphaning the report as audit trail.
      assert closed.commission_id == nil
      assert Enum.all?(Report.target_columns(), &is_nil(Map.get(closed, &1)))

      refute Repo.get(Commission, commission.id)
    end
  end

  describe "new_item/2" do
    test "the owner loads the item form" do
      user = verified_user_with_link()
      commission = commission_fixture(user)

      assert {:ok, %Ecto.Changeset{data: item}} = Commissions.new_item(actor(user), user.slug)

      assert item.commission.user.id == user.id
      assert item.commission.id == commission.id
    end

    test "items can be edited by moderators and admins" do
      user = verified_user_with_link()
      commission_fixture(user)

      for staff <- [moderator_user_fixture(), admin_user_fixture()] do
        assert {:ok, _changeset} = Commissions.new_item(actor(staff), user.slug)
      end
    end

    test "an actor without a fingerprint still gets the form" do
      user = verified_user_with_link()
      commission_fixture(user)

      assert {:ok, _} = Commissions.new_item(actor(user, fingerprint: nil), user.slug)
    end
  end

  describe "create_item/3" do
    test "the owner adds an item" do
      user = verified_user_with_link()
      commission = commission_fixture(user)

      assert {:ok, item} =
               Commissions.create_item(actor(user), user.slug, item_params())

      assert item.commission.user.id == user.id

      assert Repo.aggregate(from(i in Item, where: i.commission_id == ^commission.id), :count) ==
               1
    end

    test "validation errors retain the parent association" do
      user = verified_user_with_link()
      commission = commission_fixture(user)

      assert {:error, %Ecto.Changeset{data: item} = changeset} =
               Commissions.create_item(actor(user), user.slug, %{})

      assert item.commission.user.id == user.id
      assert item.commission.id == commission.id
      refute changeset.valid?
    end
  end

  describe "edit_item/3" do
    test "the owner loads an item for editing" do
      user = verified_user_with_link()
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      assert {:ok, %Ecto.Changeset{data: item}} =
               Commissions.edit_item(actor(user), user.slug, "#{item.id}")

      assert item.commission.user.id == user.id
      assert item.id == item.id
    end

    test "malformed, absent, and wrong-commission item IDs are not found" do
      user = verified_user_with_link()
      commission_fixture(user)
      other_user = verified_user_with_link()
      other_item = other_user |> commission_fixture() |> commission_item_fixture()

      for id <- ["bad", "2147483647", "#{other_item.id}"] do
        assert Commissions.edit_item(actor(user), user.slug, id) ==
                 {:error, :not_found}
      end
    end

    test "an actor without a fingerprint still gets the form" do
      user = verified_user_with_link()
      item = user |> commission_fixture() |> commission_item_fixture()

      assert {:ok, _} =
               Commissions.edit_item(actor(user, fingerprint: nil), user.slug, "#{item.id}")
    end
  end

  describe "delete_item/3" do
    test "the owner deletes an item" do
      user = verified_user_with_link()
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      assert {:ok, deleted_item} = Commissions.delete_item(actor(user), user.slug, "#{item.id}")
      assert deleted_item.commission.user.id == user.id
      assert Repo.get(Item, item.id) == nil
    end

    test "malformed, absent, and wrong-commission IDs are not found" do
      user = verified_user_with_link()
      commission_fixture(user)
      other_user = verified_user_with_link()
      other_item = other_user |> commission_fixture() |> commission_item_fixture()

      for id <- ["bad", "2147483647", "#{other_item.id}"] do
        assert Commissions.delete_item(actor(user), user.slug, id) == {:error, :not_found}
      end

      assert Repo.get(Item, other_item.id)
    end
  end

  describe "update_item/4" do
    test "the owner updates an item" do
      user = verified_user_with_link()
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      assert {:ok, item} =
               Commissions.update_item(actor(user), user.slug, "#{item.id}", %{
                 "description" => "Updated description"
               })

      assert item.commission.user.id == user.id
      assert Repo.get!(Item, item.id).description == "Updated description"
    end

    test "malformed, absent, and wrong-commission IDs are not found" do
      user = verified_user_with_link()
      commission_fixture(user)
      other_item = verified_user_with_link() |> commission_fixture() |> commission_item_fixture()

      for id <- ["bad", "2147483647", "#{other_item.id}"] do
        assert Commissions.update_item(actor(user), user.slug, id, item_params()) ==
                 {:error, :not_found}
      end

      assert Repo.get(Item, other_item.id)
    end
  end

  describe "list_commissions/3" do
    @pagination [page: 1, page_size: 25]

    # A commission the directory query surfaces: open, with an item, whose owner
    # has recent IP activity (the query excludes artists idle over two weeks).
    defp directory_commission do
      user = verified_user_with_link()
      commission = commission_fixture(user)
      commission_item_fixture(commission)
      user_ip_fixture(user)
      {user, commission}
    end

    test "an empty search returns a page and a fresh search changeset" do
      {_user, commission} = directory_commission()

      assert {:ok, %Directory{} = directory} =
               Commissions.list_commissions(actor(), %{}, @pagination)

      assert commission.id in Enum.map(directory.commissions.entries, & &1.id)
      assert %Ecto.Changeset{} = directory.changeset
      assert directory.current_user == nil
    end

    test "an invalid search returns a blank page and the invalid changeset" do
      directory_commission()

      assert {:ok, %Directory{} = directory} =
               Commissions.list_commissions(
                 actor(),
                 %{"price_min" => "not-a-number"},
                 @pagination
               )

      assert directory.commissions == nil
      refute directory.changeset.valid?
    end

    test "returns the signed-in viewer with their commission preloaded" do
      viewer = confirmed_user_fixture()
      commission_fixture(viewer)

      assert {:ok, %Directory{current_user: current_user}} =
               Commissions.list_commissions(actor(viewer), %{}, @pagination)

      refute match?(%Ecto.Association.NotLoaded{}, current_user.commission)
      assert current_user.commission.user_id == viewer.id
    end

    test "excludes commissions belonging to deactivated profiles" do
      {user, commission} = directory_commission()

      user
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update!()

      assert {:ok, %Directory{} = directory} =
               Commissions.list_commissions(actor(), %{}, @pagination)

      refute commission.id in Enum.map(directory.commissions.entries, & &1.id)
    end
  end
end
