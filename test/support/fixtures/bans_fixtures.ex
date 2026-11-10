defmodule Philomena.BansFixtures do
  @moduledoc """
  This module defines test helpers for creating
  ban rows for context tests without retaining moderation-log side effects.
  """

  alias Philomena.Bans
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo

  # Context writes create moderation logs. Fixtures remove only the log coupled
  # to their own insert so tests can assert the exact count produced by the
  # operation under test while still exercising the public context boundary.

  @doc """
  Creates a user ban against `target` (a fresh `confirmed_user_fixture/0`
  when `nil`), created by a fresh admin.
  """
  def user_ban_fixture(target \\ nil, attrs \\ %{}) do
    target = target || Philomena.UsersFixtures.confirmed_user_fixture()

    creator = Philomena.UsersFixtures.admin_user_fixture()

    {:ok, ban} =
      Bans.create_user_ban(
        Philomena.AttributionFixtures.actor(creator),
        target.id,
        Enum.into(attrs, %{
          "reason" => "Test ban reason",
          "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    delete_creation_log!(creator.id, "Admin.UserBan:create", ban.generated_ban_id)
    ban
  end

  @doc """
  Creates a subnet ban, created by a fresh admin.
  """
  def subnet_ban_fixture(attrs \\ %{}) do
    creator = Philomena.UsersFixtures.admin_user_fixture()

    {:ok, ban} =
      Bans.create_subnet_ban(
        Philomena.AttributionFixtures.actor(creator),
        Enum.into(attrs, %{
          "specification" => "203.0.113.0/24",
          "reason" => "Test subnet reason",
          "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    delete_creation_log!(creator.id, "Admin.SubnetBan:create", ban.generated_ban_id)
    ban
  end

  @doc """
  Creates a fingerprint ban, created by a fresh admin.
  """
  def fingerprint_ban_fixture(attrs \\ %{}) do
    creator = Philomena.UsersFixtures.admin_user_fixture()

    {:ok, ban} =
      Bans.create_fingerprint_ban(
        Philomena.AttributionFixtures.actor(creator),
        Enum.into(attrs, %{
          "fingerprint" => "d015c342859dde3",
          "reason" => "Test fingerprint reason",
          "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    delete_creation_log!(creator.id, "Admin.FingerprintBan:create", ban.generated_ban_id)
    ban
  end

  defp delete_creation_log!(creator_id, type, generated_ban_id) do
    body = "Created a #{ban_kind(type)} ban #{generated_ban_id}"

    ModerationLog
    |> Repo.get_by!(user_id: creator_id, type: type, body: body)
    |> Repo.delete!()
  end

  defp ban_kind("Admin.UserBan:create"), do: "user"
  defp ban_kind("Admin.SubnetBan:create"), do: "subnet"
  defp ban_kind("Admin.FingerprintBan:create"), do: "fingerprint"
end
