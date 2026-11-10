defmodule Mix.Tasks.Search.Status do
  use Mix.Task

  alias Philomena.SearchMigrator

  @shortdoc "Prints the migration state of every search index."
  @moduledoc """
  Shows, for each search index: the physical index serving reads, its live
  mapping version, the version declared in code, the action `mix search.migrate`
  would take, and any orphan indices. In production, use
  `Philomena.Release.search_status/0` instead.
  """
  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    Enum.each(SearchMigrator.status(), fn row ->
      Mix.shell().info(
        "#{row.alias}: live=#{row.live_physical || "(none)"} " <>
          "v#{row.live_version || "?"} desired=v#{row.desired_version} " <>
          "action=#{inspect(row.action)} orphans=#{inspect(row.orphans)}"
      )
    end)
  end
end
