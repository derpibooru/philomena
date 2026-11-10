defmodule Philomena.ModerationLogsTest do
  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo

  describe "moderation_logs" do
    test "create_moderation_log/4 with valid data creates a moderation_log" do
      user = user_fixture()

      assert {:ok, %ModerationLog{} = _moderation_log} =
               ModerationLogs.create_moderation_log(
                 user,
                 "User:update",
                 "/path/to/subject",
                 "Updated user"
               )
    end

    test "create_moderation_log/4 with invalid data returns error changeset" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               ModerationLogs.create_moderation_log(user, nil, nil, nil)
    end
  end

  describe "put_log/6" do
    test "composes an audit insert with actor attribution" do
      user = admin_user_fixture()

      assert {:ok, %{audit: %ModerationLog{} = log}} =
               Multi.new()
               |> ModerationLogs.put_log(
                 :audit,
                 actor(user),
                 "User:update",
                 "/profiles/example",
                 "Updated user"
               )
               |> Multi.transact()

      assert log.user_id == user.id
    end

    test "an invalid audit record rolls back preceding database steps" do
      user = admin_user_fixture()
      deleted_actor = admin_user_fixture()
      Repo.delete!(deleted_actor)

      marker =
        ModerationLog.changeset(
          %ModerationLog{user_id: user.id},
          %{type: "Marker:create", subject_path: "/marker", body: "must roll back"}
        )

      assert {:error, :audit, %Ecto.Changeset{}, %{action: %ModerationLog{}}} =
               Multi.new()
               |> Multi.insert(:action, marker)
               |> ModerationLogs.put_log(
                 :audit,
                 actor(deleted_actor),
                 "User:update",
                 "/profiles/deleted",
                 "Must fail attribution"
               )
               |> Multi.transact()

      refute Repo.get_by(ModerationLog, body: "must roll back")
    end
  end

  describe "list_moderation_logs/2" do
    alias Scrivener.Page

    @pagination [page: 1, page_size: 25]

    defp logged_entry do
      {:ok, log} =
        ModerationLogs.create_moderation_log(
          admin_user_fixture(),
          "User:update",
          "/path/to/subject",
          "Updated user"
        )

      log
    end

    test "a moderator gets the paginated logs" do
      log = logged_entry()

      assert {:ok, %Page{} = page} =
               ModerationLogs.list_moderation_logs(actor(moderator_user_fixture()), @pagination)

      assert log.id in Enum.map(page.entries, & &1.id)
    end

    test "an admin gets the paginated logs" do
      assert {:ok, %Page{}} =
               ModerationLogs.list_moderation_logs(actor(admin_user_fixture()), @pagination)
    end

    test "a regular user is unauthorized" do
      assert ModerationLogs.list_moderation_logs(actor(confirmed_user_fixture()), @pagination) ==
               {:error, :unauthorized}
    end

    test "an anonymous viewer is unauthorized" do
      assert ModerationLogs.list_moderation_logs(actor(), @pagination) == {:error, :unauthorized}
    end

    test "orders equal-timestamp entries by newest ID and excludes expired logs" do
      user = admin_user_fixture()
      timestamp = DateTime.utc_now(:second)

      older =
        Repo.insert!(%ModerationLog{
          user_id: user.id,
          type: "Order:test",
          subject_path: "/older",
          body: "older id",
          created_at: timestamp
        })

      newer =
        Repo.insert!(%ModerationLog{
          user_id: user.id,
          type: "Order:test",
          subject_path: "/newer",
          body: "newer id",
          created_at: timestamp
        })

      Repo.insert!(%ModerationLog{
        user_id: user.id,
        type: "Order:test",
        subject_path: "/expired",
        body: "expired",
        created_at: DateTime.add(timestamp, -15, :day)
      })

      assert {:ok, page} =
               ModerationLogs.list_moderation_logs(actor(moderator_user_fixture()), @pagination)

      ids = Enum.map(page.entries, & &1.id)
      assert Enum.take(ids, 2) == [newer.id, older.id]
      refute Enum.any?(page.entries, &(&1.body == "expired"))
    end
  end

  describe "cleanup!/0" do
    test "deletes only records older than the retention window" do
      user = admin_user_fixture()
      now = DateTime.utc_now(:second)

      recent =
        Repo.insert!(%ModerationLog{
          user_id: user.id,
          type: "Cleanup:test",
          subject_path: "/recent",
          body: "recent",
          created_at: now
        })

      expired =
        Repo.insert!(%ModerationLog{
          user_id: user.id,
          type: "Cleanup:test",
          subject_path: "/expired",
          body: "expired",
          created_at: DateTime.add(now, -15, :day)
        })

      assert {1, nil} = ModerationLogs.cleanup!()
      assert Repo.get(ModerationLog, recent.id)
      refute Repo.get(ModerationLog, expired.id)
    end
  end
end
