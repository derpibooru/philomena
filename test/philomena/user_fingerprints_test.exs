defmodule Philomena.UserFingerprintsTest do
  use Philomena.DataCase

  alias Philomena.UserFingerprints

  describe "user_fingerprints" do
    alias Philomena.UserFingerprints.UserFingerprint

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_fingerprint_fixture(attrs \\ %{}) do
      {:ok, user_fingerprint} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserFingerprints.create_user_fingerprint()

      user_fingerprint
    end

    test "list_user_fingerprints/0 returns all user_fingerprints" do
      user_fingerprint = user_fingerprint_fixture()
      assert UserFingerprints.list_user_fingerprints() == [user_fingerprint]
    end

    test "get_user_fingerprint!/1 returns the user_fingerprint with given id" do
      user_fingerprint = user_fingerprint_fixture()
      assert UserFingerprints.get_user_fingerprint!(user_fingerprint.id) == user_fingerprint
    end

    test "create_user_fingerprint/1 with valid data creates a user_fingerprint" do
      assert {:ok, %UserFingerprint{} = user_fingerprint} = UserFingerprints.create_user_fingerprint(@valid_attrs)
    end

    test "create_user_fingerprint/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserFingerprints.create_user_fingerprint(@invalid_attrs)
    end

    test "update_user_fingerprint/2 with valid data updates the user_fingerprint" do
      user_fingerprint = user_fingerprint_fixture()
      assert {:ok, %UserFingerprint{} = user_fingerprint} = UserFingerprints.update_user_fingerprint(user_fingerprint, @update_attrs)
    end

    test "update_user_fingerprint/2 with invalid data returns error changeset" do
      user_fingerprint = user_fingerprint_fixture()
      assert {:error, %Ecto.Changeset{}} = UserFingerprints.update_user_fingerprint(user_fingerprint, @invalid_attrs)
      assert user_fingerprint == UserFingerprints.get_user_fingerprint!(user_fingerprint.id)
    end

    test "delete_user_fingerprint/1 deletes the user_fingerprint" do
      user_fingerprint = user_fingerprint_fixture()
      assert {:ok, %UserFingerprint{}} = UserFingerprints.delete_user_fingerprint(user_fingerprint)
      assert_raise Ecto.NoResultsError, fn -> UserFingerprints.get_user_fingerprint!(user_fingerprint.id) end
    end

    test "change_user_fingerprint/1 returns a user_fingerprint changeset" do
      user_fingerprint = user_fingerprint_fixture()
      assert %Ecto.Changeset{} = UserFingerprints.change_user_fingerprint(user_fingerprint)
    end
  end
end
