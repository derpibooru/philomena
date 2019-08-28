defmodule Philomena.AdvertsTest do
  use Philomena.DataCase

  alias Philomena.Adverts

  describe "adverts" do
    alias Philomena.Adverts.Advert

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def advert_fixture(attrs \\ %{}) do
      {:ok, advert} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Adverts.create_advert()

      advert
    end

    test "list_adverts/0 returns all adverts" do
      advert = advert_fixture()
      assert Adverts.list_adverts() == [advert]
    end

    test "get_advert!/1 returns the advert with given id" do
      advert = advert_fixture()
      assert Adverts.get_advert!(advert.id) == advert
    end

    test "create_advert/1 with valid data creates a advert" do
      assert {:ok, %Advert{} = advert} = Adverts.create_advert(@valid_attrs)
    end

    test "create_advert/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Adverts.create_advert(@invalid_attrs)
    end

    test "update_advert/2 with valid data updates the advert" do
      advert = advert_fixture()
      assert {:ok, %Advert{} = advert} = Adverts.update_advert(advert, @update_attrs)
    end

    test "update_advert/2 with invalid data returns error changeset" do
      advert = advert_fixture()
      assert {:error, %Ecto.Changeset{}} = Adverts.update_advert(advert, @invalid_attrs)
      assert advert == Adverts.get_advert!(advert.id)
    end

    test "delete_advert/1 deletes the advert" do
      advert = advert_fixture()
      assert {:ok, %Advert{}} = Adverts.delete_advert(advert)
      assert_raise Ecto.NoResultsError, fn -> Adverts.get_advert!(advert.id) end
    end

    test "change_advert/1 returns a advert changeset" do
      advert = advert_fixture()
      assert %Ecto.Changeset{} = Adverts.change_advert(advert)
    end
  end
end
