defmodule Philomena.ImageIntensitiesTest do
  use Philomena.DataCase

  alias Philomena.ImageIntensities

  describe "image_intensities" do
    alias Philomena.ImageIntensities.ImageIntensity

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def image_intensity_fixture(attrs \\ %{}) do
      {:ok, image_intensity} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ImageIntensities.create_image_intensity()

      image_intensity
    end

    test "list_image_intensities/0 returns all image_intensities" do
      image_intensity = image_intensity_fixture()
      assert ImageIntensities.list_image_intensities() == [image_intensity]
    end

    test "get_image_intensity!/1 returns the image_intensity with given id" do
      image_intensity = image_intensity_fixture()
      assert ImageIntensities.get_image_intensity!(image_intensity.id) == image_intensity
    end

    test "create_image_intensity/1 with valid data creates a image_intensity" do
      assert {:ok, %ImageIntensity{} = image_intensity} = ImageIntensities.create_image_intensity(@valid_attrs)
    end

    test "create_image_intensity/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ImageIntensities.create_image_intensity(@invalid_attrs)
    end

    test "update_image_intensity/2 with valid data updates the image_intensity" do
      image_intensity = image_intensity_fixture()
      assert {:ok, %ImageIntensity{} = image_intensity} = ImageIntensities.update_image_intensity(image_intensity, @update_attrs)
    end

    test "update_image_intensity/2 with invalid data returns error changeset" do
      image_intensity = image_intensity_fixture()
      assert {:error, %Ecto.Changeset{}} = ImageIntensities.update_image_intensity(image_intensity, @invalid_attrs)
      assert image_intensity == ImageIntensities.get_image_intensity!(image_intensity.id)
    end

    test "delete_image_intensity/1 deletes the image_intensity" do
      image_intensity = image_intensity_fixture()
      assert {:ok, %ImageIntensity{}} = ImageIntensities.delete_image_intensity(image_intensity)
      assert_raise Ecto.NoResultsError, fn -> ImageIntensities.get_image_intensity!(image_intensity.id) end
    end

    test "change_image_intensity/1 returns a image_intensity changeset" do
      image_intensity = image_intensity_fixture()
      assert %Ecto.Changeset{} = ImageIntensities.change_image_intensity(image_intensity)
    end
  end
end
