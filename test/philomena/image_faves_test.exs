defmodule Philomena.ImageFavesTest do
  use Philomena.DataCase

  alias Philomena.ImageFaves

  describe "image_faves" do
    alias Philomena.ImageFaves.ImageFave

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def image_fave_fixture(attrs \\ %{}) do
      {:ok, image_fave} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ImageFaves.create_image_fave()

      image_fave
    end

    test "list_image_faves/0 returns all image_faves" do
      image_fave = image_fave_fixture()
      assert ImageFaves.list_image_faves() == [image_fave]
    end

    test "get_image_fave!/1 returns the image_fave with given id" do
      image_fave = image_fave_fixture()
      assert ImageFaves.get_image_fave!(image_fave.id) == image_fave
    end

    test "create_image_fave/1 with valid data creates a image_fave" do
      assert {:ok, %ImageFave{} = image_fave} = ImageFaves.create_image_fave(@valid_attrs)
    end

    test "create_image_fave/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ImageFaves.create_image_fave(@invalid_attrs)
    end

    test "update_image_fave/2 with valid data updates the image_fave" do
      image_fave = image_fave_fixture()
      assert {:ok, %ImageFave{} = image_fave} = ImageFaves.update_image_fave(image_fave, @update_attrs)
    end

    test "update_image_fave/2 with invalid data returns error changeset" do
      image_fave = image_fave_fixture()
      assert {:error, %Ecto.Changeset{}} = ImageFaves.update_image_fave(image_fave, @invalid_attrs)
      assert image_fave == ImageFaves.get_image_fave!(image_fave.id)
    end

    test "delete_image_fave/1 deletes the image_fave" do
      image_fave = image_fave_fixture()
      assert {:ok, %ImageFave{}} = ImageFaves.delete_image_fave(image_fave)
      assert_raise Ecto.NoResultsError, fn -> ImageFaves.get_image_fave!(image_fave.id) end
    end

    test "change_image_fave/1 returns a image_fave changeset" do
      image_fave = image_fave_fixture()
      assert %Ecto.Changeset{} = ImageFaves.change_image_fave(image_fave)
    end
  end
end
