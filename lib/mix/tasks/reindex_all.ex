defmodule Mix.Tasks.ReindexAll do
  use Mix.Task

  alias Philomena.SearchIndexer

  @shortdoc "Destroys and recreates all OpenSearch indices."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(args) do
    if Mix.env() == :prod and not Enum.member?(args, "--i-know-what-im-doing") do
      raise "do not run this task unless you know what you're doing"
    end

    SearchIndexer.recreate_reindex_all_destructive!(maintenance: false)
  end
end
