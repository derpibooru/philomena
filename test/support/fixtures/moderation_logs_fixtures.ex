defmodule Philomena.ModerationLogsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.ModerationLogs` context.
  """

  @doc """
  Generate a moderation_log.
  """
  def moderation_log_fixture(attrs \\ %{}) do
    {:ok, moderation_log} =
      attrs
      |> Enum.into(%{})
      |> Philomena.ModerationLogs.create_moderation_log()

    moderation_log
  end
end
