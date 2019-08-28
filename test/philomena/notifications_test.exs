defmodule Philomena.NotificationsTest do
  use Philomena.DataCase

  alias Philomena.Notifications

  describe "notifications" do
    alias Philomena.Notifications.Notification

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def notification_fixture(attrs \\ %{}) do
      {:ok, notification} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Notifications.create_notification()

      notification
    end

    test "list_notifications/0 returns all notifications" do
      notification = notification_fixture()
      assert Notifications.list_notifications() == [notification]
    end

    test "get_notification!/1 returns the notification with given id" do
      notification = notification_fixture()
      assert Notifications.get_notification!(notification.id) == notification
    end

    test "create_notification/1 with valid data creates a notification" do
      assert {:ok, %Notification{} = notification} =
               Notifications.create_notification(@valid_attrs)
    end

    test "create_notification/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Notifications.create_notification(@invalid_attrs)
    end

    test "update_notification/2 with valid data updates the notification" do
      notification = notification_fixture()

      assert {:ok, %Notification{} = notification} =
               Notifications.update_notification(notification, @update_attrs)
    end

    test "update_notification/2 with invalid data returns error changeset" do
      notification = notification_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Notifications.update_notification(notification, @invalid_attrs)

      assert notification == Notifications.get_notification!(notification.id)
    end

    test "delete_notification/1 deletes the notification" do
      notification = notification_fixture()
      assert {:ok, %Notification{}} = Notifications.delete_notification(notification)
      assert_raise Ecto.NoResultsError, fn -> Notifications.get_notification!(notification.id) end
    end

    test "change_notification/1 returns a notification changeset" do
      notification = notification_fixture()
      assert %Ecto.Changeset{} = Notifications.change_notification(notification)
    end
  end

  describe "unread_notifications" do
    alias Philomena.Notifications.UnreadNotification

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def unread_notification_fixture(attrs \\ %{}) do
      {:ok, unread_notification} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Notifications.create_unread_notification()

      unread_notification
    end

    test "list_unread_notifications/0 returns all unread_notifications" do
      unread_notification = unread_notification_fixture()
      assert Notifications.list_unread_notifications() == [unread_notification]
    end

    test "get_unread_notification!/1 returns the unread_notification with given id" do
      unread_notification = unread_notification_fixture()
      assert Notifications.get_unread_notification!(unread_notification.id) == unread_notification
    end

    test "create_unread_notification/1 with valid data creates a unread_notification" do
      assert {:ok, %UnreadNotification{} = unread_notification} =
               Notifications.create_unread_notification(@valid_attrs)
    end

    test "create_unread_notification/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Notifications.create_unread_notification(@invalid_attrs)
    end

    test "update_unread_notification/2 with valid data updates the unread_notification" do
      unread_notification = unread_notification_fixture()

      assert {:ok, %UnreadNotification{} = unread_notification} =
               Notifications.update_unread_notification(unread_notification, @update_attrs)
    end

    test "update_unread_notification/2 with invalid data returns error changeset" do
      unread_notification = unread_notification_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Notifications.update_unread_notification(unread_notification, @invalid_attrs)

      assert unread_notification == Notifications.get_unread_notification!(unread_notification.id)
    end

    test "delete_unread_notification/1 deletes the unread_notification" do
      unread_notification = unread_notification_fixture()

      assert {:ok, %UnreadNotification{}} =
               Notifications.delete_unread_notification(unread_notification)

      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_unread_notification!(unread_notification.id)
      end
    end

    test "change_unread_notification/1 returns a unread_notification changeset" do
      unread_notification = unread_notification_fixture()
      assert %Ecto.Changeset{} = Notifications.change_unread_notification(unread_notification)
    end
  end
end
