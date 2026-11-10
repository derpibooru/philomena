defmodule Philomena.UserNameChangesTest do
  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.UserNameChanges
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Users

  @pagination %{page: 1, page_size: 1}

  defp record_name!(user) do
    {:ok, %{name_change: change}} =
      Multi.new()
      |> UserNameChanges.record_rename(:name_change, user)
      |> Multi.transact()

    change
  end

  describe "record_rename/3" do
    test "records the exact prior name as an owning transaction step" do
      user = confirmed_user_fixture(%{name: "CaseSensitiveName"})

      change = record_name!(user)

      assert change.user_id == user.id
      assert change.name == "CaseSensitiveName"
    end

    test "rolls back when a later owning transaction step fails" do
      user = confirmed_user_fixture()

      assert {:error, :later_step, :forced, %{}} =
               Multi.new()
               |> UserNameChanges.record_rename(:name_change, user)
               |> Multi.run(:later_step, fn _repo, _changes -> {:error, :forced} end)
               |> Multi.transact()

      refute Repo.get_by(UserNameChange, user_id: user.id)
    end

    test "Users records case-only renames and duplicate-name failures atomically" do
      user = confirmed_user_fixture(%{name: "MixedCaseRename"})
      user = Users.fetch_user_for_worker!(user.id)

      assert {:ok, renamed} = Users.update_name(actor(user), %{"name" => "mixedcaserename"})
      assert renamed.name == "mixedcaserename"
      assert Repo.get_by(UserNameChange, user_id: user.id, name: "MixedCaseRename")

      occupied = confirmed_user_fixture(%{name: "AlreadyTakenName"})
      other = confirmed_user_fixture(%{name: "RenameMustRollback"})
      other = Users.fetch_user_for_worker!(other.id)

      assert {:error, %Ecto.Changeset{}} =
               Users.update_name(actor(other), %{"name" => occupied.name})

      refute Repo.get_by(UserNameChange, user_id: other.id)
      assert Users.fetch_user_for_worker!(other.id).name == "RenameMustRollback"
    end
  end

  describe "load_history/3" do
    test "a moderator gets newest-first paginated history" do
      user = confirmed_user_fixture()
      older = record_name!(%{user | name: "older-name"})
      newer = record_name!(%{user | name: "newer-name"})

      assert {:ok, first_page} =
               UserNameChanges.load_history(actor(moderator_user_fixture()), user, @pagination)

      assert Enum.map(first_page.entries, & &1.id) == [newer.id]
      assert first_page.total_entries == 2

      assert {:ok, second_page} =
               UserNameChanges.load_history(
                 actor(admin_user_fixture()),
                 user,
                 %{page: 2, page_size: 1}
               )

      assert Enum.map(second_page.entries, & &1.id) == [older.id]
    end

    test "anonymous and ordinary viewers are unauthorized" do
      user = confirmed_user_fixture()

      assert UserNameChanges.load_history(actor(), user, @pagination) ==
               {:error, :unauthorized}

      assert UserNameChanges.load_history(
               actor(confirmed_user_fixture()),
               user,
               @pagination
             ) == {:error, :unauthorized}
    end
  end
end
