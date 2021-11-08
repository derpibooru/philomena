defmodule Philomena.ModerationLogsTest do
  use Philomena.DataCase

  alias Philomena.ModerationLogs

  describe "moderation_logs" do
    alias Philomena.ModerationLogs.ModerationLog

    import Philomena.UsersFixtures

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
end
