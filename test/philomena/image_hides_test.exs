defmodule Philomena.ImageHidesTest do
  use Philomena.DataCase

  alias Philomena.ImageHides

  describe "image_hides" do
    alias Philomena.ImageHides.ImageHide

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def image_hide_fixture(attrs \\ %{}) do
      {:ok, image_hide} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ImageHides.create_image_hide()

      image_hide
    end

    test "list_image_hides/0 returns all image_hides" do
      image_hide = image_hide_fixture()
      assert ImageHides.list_image_hides() == [image_hide]
    end

    test "get_image_hide!/1 returns the image_hide with given id" do
      image_hide = image_hide_fixture()
      assert ImageHides.get_image_hide!(image_hide.id) == image_hide
    end

    test "create_image_hide/1 with valid data creates a image_hide" do
      assert {:ok, %ImageHide{} = image_hide} = ImageHides.create_image_hide(@valid_attrs)
    end

    test "create_image_hide/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ImageHides.create_image_hide(@invalid_attrs)
    end

    test "update_image_hide/2 with valid data updates the image_hide" do
      image_hide = image_hide_fixture()
      assert {:ok, %ImageHide{} = image_hide} = ImageHides.update_image_hide(image_hide, @update_attrs)
    end

    test "update_image_hide/2 with invalid data returns error changeset" do
      image_hide = image_hide_fixture()
      assert {:error, %Ecto.Changeset{}} = ImageHides.update_image_hide(image_hide, @invalid_attrs)
      assert image_hide == ImageHides.get_image_hide!(image_hide.id)
    end

    test "delete_image_hide/1 deletes the image_hide" do
      image_hide = image_hide_fixture()
      assert {:ok, %ImageHide{}} = ImageHides.delete_image_hide(image_hide)
      assert_raise Ecto.NoResultsError, fn -> ImageHides.get_image_hide!(image_hide.id) end
    end

    test "change_image_hide/1 returns a image_hide changeset" do
      image_hide = image_hide_fixture()
      assert %Ecto.Changeset{} = ImageHides.change_image_hide(image_hide)
    end
  end
end
