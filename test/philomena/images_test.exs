defmodule Philomena.ImagesTest do
  use Philomena.DataCase

  alias Philomena.Images

  describe "images" do
    alias Philomena.Images.Image

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def image_fixture(attrs \\ %{}) do
      {:ok, image} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Images.create_image()

      image
    end

    test "list_images/0 returns all images" do
      image = image_fixture()
      assert Images.list_images() == [image]
    end

    test "get_image!/1 returns the image with given id" do
      image = image_fixture()
      assert Images.get_image!(image.id) == image
    end

    test "create_image/1 with valid data creates a image" do
      assert {:ok, %Image{} = image} = Images.create_image(@valid_attrs)
    end

    test "create_image/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Images.create_image(@invalid_attrs)
    end

    test "update_image/2 with valid data updates the image" do
      image = image_fixture()
      assert {:ok, %Image{} = image} = Images.update_image(image, @update_attrs)
    end

    test "update_image/2 with invalid data returns error changeset" do
      image = image_fixture()
      assert {:error, %Ecto.Changeset{}} = Images.update_image(image, @invalid_attrs)
      assert image == Images.get_image!(image.id)
    end

    test "delete_image/1 deletes the image" do
      image = image_fixture()
      assert {:ok, %Image{}} = Images.delete_image(image)
      assert_raise Ecto.NoResultsError, fn -> Images.get_image!(image.id) end
    end

    test "change_image/1 returns a image changeset" do
      image = image_fixture()
      assert %Ecto.Changeset{} = Images.change_image(image)
    end
  end

  describe "image_features" do
    alias Philomena.Images.Features

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def features_fixture(attrs \\ %{}) do
      {:ok, features} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Images.create_features()

      features
    end

    test "list_image_features/0 returns all image_features" do
      features = features_fixture()
      assert Images.list_image_features() == [features]
    end

    test "get_features!/1 returns the features with given id" do
      features = features_fixture()
      assert Images.get_features!(features.id) == features
    end

    test "create_features/1 with valid data creates a features" do
      assert {:ok, %Features{} = features} = Images.create_features(@valid_attrs)
    end

    test "create_features/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Images.create_features(@invalid_attrs)
    end

    test "update_features/2 with valid data updates the features" do
      features = features_fixture()
      assert {:ok, %Features{} = features} = Images.update_features(features, @update_attrs)
    end

    test "update_features/2 with invalid data returns error changeset" do
      features = features_fixture()
      assert {:error, %Ecto.Changeset{}} = Images.update_features(features, @invalid_attrs)
      assert features == Images.get_features!(features.id)
    end

    test "delete_features/1 deletes the features" do
      features = features_fixture()
      assert {:ok, %Features{}} = Images.delete_features(features)
      assert_raise Ecto.NoResultsError, fn -> Images.get_features!(features.id) end
    end

    test "change_features/1 returns a features changeset" do
      features = features_fixture()
      assert %Ecto.Changeset{} = Images.change_features(features)
    end
  end

  describe "image_intensities" do
    alias Philomena.Images.Intensities

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def intensities_fixture(attrs \\ %{}) do
      {:ok, intensities} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Images.create_intensities()

      intensities
    end

    test "list_image_intensities/0 returns all image_intensities" do
      intensities = intensities_fixture()
      assert Images.list_image_intensities() == [intensities]
    end

    test "get_intensities!/1 returns the intensities with given id" do
      intensities = intensities_fixture()
      assert Images.get_intensities!(intensities.id) == intensities
    end

    test "create_intensities/1 with valid data creates a intensities" do
      assert {:ok, %Intensities{} = intensities} = Images.create_intensities(@valid_attrs)
    end

    test "create_intensities/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Images.create_intensities(@invalid_attrs)
    end

    test "update_intensities/2 with valid data updates the intensities" do
      intensities = intensities_fixture()
      assert {:ok, %Intensities{} = intensities} = Images.update_intensities(intensities, @update_attrs)
    end

    test "update_intensities/2 with invalid data returns error changeset" do
      intensities = intensities_fixture()
      assert {:error, %Ecto.Changeset{}} = Images.update_intensities(intensities, @invalid_attrs)
      assert intensities == Images.get_intensities!(intensities.id)
    end

    test "delete_intensities/1 deletes the intensities" do
      intensities = intensities_fixture()
      assert {:ok, %Intensities{}} = Images.delete_intensities(intensities)
      assert_raise Ecto.NoResultsError, fn -> Images.get_intensities!(intensities.id) end
    end

    test "change_intensities/1 returns a intensities changeset" do
      intensities = intensities_fixture()
      assert %Ecto.Changeset{} = Images.change_intensities(intensities)
    end
  end

  describe "image_subscriptions" do
    alias Philomena.Images.Subscription

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def subscription_fixture(attrs \\ %{}) do
      {:ok, subscription} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Images.create_subscription()

      subscription
    end

    test "list_image_subscriptions/0 returns all image_subscriptions" do
      subscription = subscription_fixture()
      assert Images.list_image_subscriptions() == [subscription]
    end

    test "get_subscription!/1 returns the subscription with given id" do
      subscription = subscription_fixture()
      assert Images.get_subscription!(subscription.id) == subscription
    end

    test "create_subscription/1 with valid data creates a subscription" do
      assert {:ok, %Subscription{} = subscription} = Images.create_subscription(@valid_attrs)
    end

    test "create_subscription/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Images.create_subscription(@invalid_attrs)
    end

    test "update_subscription/2 with valid data updates the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{} = subscription} = Images.update_subscription(subscription, @update_attrs)
    end

    test "update_subscription/2 with invalid data returns error changeset" do
      subscription = subscription_fixture()
      assert {:error, %Ecto.Changeset{}} = Images.update_subscription(subscription, @invalid_attrs)
      assert subscription == Images.get_subscription!(subscription.id)
    end

    test "delete_subscription/1 deletes the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{}} = Images.delete_subscription(subscription)
      assert_raise Ecto.NoResultsError, fn -> Images.get_subscription!(subscription.id) end
    end

    test "change_subscription/1 returns a subscription changeset" do
      subscription = subscription_fixture()
      assert %Ecto.Changeset{} = Images.change_subscription(subscription)
    end
  end
end
