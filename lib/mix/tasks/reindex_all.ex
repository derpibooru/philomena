defmodule Mix.Tasks.ReindexAll do
  use Mix.Task

  alias Philomena.SearchIndexer
  alias Philomena.SearchMigrator

  @shortdoc "Applies search index migrations and reindexes all documents."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(args) do
    if Mix.env() == :prod and not Enum.member?(args, "--i-know-what-im-doing") do
      raise "do not run this task unless you know what you're doing"
    end

    SearchMigrator.migrate_all(maintenance: false)
    SearchIndexer.reindex_all(maintenance: false)
  end
end
