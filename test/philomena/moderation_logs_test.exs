defmodule Philomena.ModerationLogsTest do
  use Philomena.DataCase

  alias Philomena.ModerationLogs

  describe "moderation_logs" do
    alias Philomena.ModerationLogs.ModerationLog

    import Philomena.ModerationLogsFixtures

    @invalid_attrs %{}

    test "list_moderation_logs/0 returns all moderation_logs" do
      moderation_log = moderation_log_fixture()
      assert ModerationLogs.list_moderation_logs() == [moderation_log]
    end

    test "create_moderation_log/1 with valid data creates a moderation_log" do
      valid_attrs = %{}

      assert {:ok, %ModerationLog{} = moderation_log} =
               ModerationLogs.create_moderation_log(valid_attrs)
    end

    test "create_moderation_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ModerationLogs.create_moderation_log(@invalid_attrs)
    end
  end
end
