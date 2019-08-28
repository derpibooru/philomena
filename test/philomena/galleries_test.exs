defmodule Philomena.GalleriesTest do
  use Philomena.DataCase

  alias Philomena.Galleries

  describe "galleries" do
    alias Philomena.Galleries.Gallery

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def gallery_fixture(attrs \\ %{}) do
      {:ok, gallery} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Galleries.create_gallery()

      gallery
    end

    test "list_galleries/0 returns all galleries" do
      gallery = gallery_fixture()
      assert Galleries.list_galleries() == [gallery]
    end

    test "get_gallery!/1 returns the gallery with given id" do
      gallery = gallery_fixture()
      assert Galleries.get_gallery!(gallery.id) == gallery
    end

    test "create_gallery/1 with valid data creates a gallery" do
      assert {:ok, %Gallery{} = gallery} = Galleries.create_gallery(@valid_attrs)
    end

    test "create_gallery/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Galleries.create_gallery(@invalid_attrs)
    end

    test "update_gallery/2 with valid data updates the gallery" do
      gallery = gallery_fixture()
      assert {:ok, %Gallery{} = gallery} = Galleries.update_gallery(gallery, @update_attrs)
    end

    test "update_gallery/2 with invalid data returns error changeset" do
      gallery = gallery_fixture()
      assert {:error, %Ecto.Changeset{}} = Galleries.update_gallery(gallery, @invalid_attrs)
      assert gallery == Galleries.get_gallery!(gallery.id)
    end

    test "delete_gallery/1 deletes the gallery" do
      gallery = gallery_fixture()
      assert {:ok, %Gallery{}} = Galleries.delete_gallery(gallery)
      assert_raise Ecto.NoResultsError, fn -> Galleries.get_gallery!(gallery.id) end
    end

    test "change_gallery/1 returns a gallery changeset" do
      gallery = gallery_fixture()
      assert %Ecto.Changeset{} = Galleries.change_gallery(gallery)
    end
  end

  describe "gallery_subscriptions" do
    alias Philomena.Galleries.Subscription

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def subscription_fixture(attrs \\ %{}) do
      {:ok, subscription} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Galleries.create_subscription()

      subscription
    end

    test "list_gallery_subscriptions/0 returns all gallery_subscriptions" do
      subscription = subscription_fixture()
      assert Galleries.list_gallery_subscriptions() == [subscription]
    end

    test "get_subscription!/1 returns the subscription with given id" do
      subscription = subscription_fixture()
      assert Galleries.get_subscription!(subscription.id) == subscription
    end

    test "create_subscription/1 with valid data creates a subscription" do
      assert {:ok, %Subscription{} = subscription} = Galleries.create_subscription(@valid_attrs)
    end

    test "create_subscription/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Galleries.create_subscription(@invalid_attrs)
    end

    test "update_subscription/2 with valid data updates the subscription" do
      subscription = subscription_fixture()

      assert {:ok, %Subscription{} = subscription} =
               Galleries.update_subscription(subscription, @update_attrs)
    end

    test "update_subscription/2 with invalid data returns error changeset" do
      subscription = subscription_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Galleries.update_subscription(subscription, @invalid_attrs)

      assert subscription == Galleries.get_subscription!(subscription.id)
    end

    test "delete_subscription/1 deletes the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{}} = Galleries.delete_subscription(subscription)
      assert_raise Ecto.NoResultsError, fn -> Galleries.get_subscription!(subscription.id) end
    end

    test "change_subscription/1 returns a subscription changeset" do
      subscription = subscription_fixture()
      assert %Ecto.Changeset{} = Galleries.change_subscription(subscription)
    end
  end
end
