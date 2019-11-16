defmodule Philomena.ImageFeaturesTest do
  use Philomena.DataCase

  alias Philomena.ImageFeatures

  describe "image_features" do
    alias Philomena.ImageFeatures.ImageFeature

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def image_feature_fixture(attrs \\ %{}) do
      {:ok, image_feature} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ImageFeatures.create_image_feature()

      image_feature
    end

    test "list_image_features/0 returns all image_features" do
      image_feature = image_feature_fixture()
      assert ImageFeatures.list_image_features() == [image_feature]
    end

    test "get_image_feature!/1 returns the image_feature with given id" do
      image_feature = image_feature_fixture()
      assert ImageFeatures.get_image_feature!(image_feature.id) == image_feature
    end

    test "create_image_feature/1 with valid data creates a image_feature" do
      assert {:ok, %ImageFeature{} = image_feature} = ImageFeatures.create_image_feature(@valid_attrs)
    end

    test "create_image_feature/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ImageFeatures.create_image_feature(@invalid_attrs)
    end

    test "update_image_feature/2 with valid data updates the image_feature" do
      image_feature = image_feature_fixture()
      assert {:ok, %ImageFeature{} = image_feature} = ImageFeatures.update_image_feature(image_feature, @update_attrs)
    end

    test "update_image_feature/2 with invalid data returns error changeset" do
      image_feature = image_feature_fixture()
      assert {:error, %Ecto.Changeset{}} = ImageFeatures.update_image_feature(image_feature, @invalid_attrs)
      assert image_feature == ImageFeatures.get_image_feature!(image_feature.id)
    end

    test "delete_image_feature/1 deletes the image_feature" do
      image_feature = image_feature_fixture()
      assert {:ok, %ImageFeature{}} = ImageFeatures.delete_image_feature(image_feature)
      assert_raise Ecto.NoResultsError, fn -> ImageFeatures.get_image_feature!(image_feature.id) end
    end

    test "change_image_feature/1 returns a image_feature changeset" do
      image_feature = image_feature_fixture()
      assert %Ecto.Changeset{} = ImageFeatures.change_image_feature(image_feature)
    end
  end
end
