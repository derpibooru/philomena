defmodule Mix.Tasks.Search.Migrate do
  use Mix.Task

  alias Philomena.SearchIndexer
  alias Philomena.SearchMigrator

  @shortdoc "Applies pending search index migrations."
  @moduledoc """
  Idempotently brings every search index to the version declared by its index
  module, creating, updating or rebuilding as needed. See
  `Philomena.SearchMigrator` for the mechanism. In production, use
  `Philomena.Release.migrate_search/0` instead.

  ## Usage

      mix search.migrate [--only images,tags] [--force] [--check]

  - `--only` restricts the run to the given (comma-separated) index names.
  - `--force` takes over migrations another run appears to have in progress.
  - `--check` performs no changes; it prints the migration status and exits
    with a non-zero status if any action is pending.
  """
  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, [], []} =
      OptionParser.parse(args, strict: [only: :string, force: :boolean, check: :boolean])

    if opts[:check] do
      check()
    else
      Enum.each(schemas(opts[:only]), fn schema ->
        SearchMigrator.migrate_schema(schema,
          maintenance: false,
          force: Keyword.get(opts, :force, false)
        )
      end)
    end
  end

  defp check do
    status = SearchMigrator.status()

    Enum.each(status, fn row ->
      Mix.shell().info(
        "#{row.alias}: live=#{row.live_physical || "(none)"} " <>
          "v#{row.live_version || "?"} desired=v#{row.desired_version} " <>
          "action=#{inspect(row.action)} orphans=#{inspect(row.orphans)}"
      )
    end)

    unless Enum.all?(status, &(&1.action == :noop and &1.orphans == [])) do
      Mix.raise("Search index migrations are pending.")
    end
  end

  defp schemas(nil), do: SearchIndexer.schemas()

  defp schemas(only) do
    names = String.split(only, ",", trim: true)

    schemas =
      Enum.filter(SearchIndexer.schemas(), fn schema ->
        Philomena.SearchPolicy.index_for(schema).index_name() in names
      end)

    if schemas == [] do
      Mix.raise("No search index matches --only #{only}")
    end

    schemas
  end
end
