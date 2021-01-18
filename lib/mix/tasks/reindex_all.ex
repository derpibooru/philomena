defmodule Mix.Tasks.ReindexAll do
  use Mix.Task

  alias Philomena.Elasticsearch

  alias Philomena.{
    Comments.Comment,
    Galleries.Gallery,
    Posts.Post,
    Images.Image,
    Reports.Report,
    Tags.Tag,
    Filters.Filter
  }

  alias Philomena.{Comments, Galleries, Posts, Images, Tags, Filters}
  alias Philomena.Polymorphic
  alias Philomena.Repo
  import Ecto.Query

  @shortdoc "Destroys and recreates all Elasticsearch indices."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(args) do
    if Mix.env() == :prod and not Enum.member?(args, "--i-know-what-im-doing") do
      raise "do not run this task unless you know what you're doing"
    end

    for {context, schema} <- [
          {Images, Image},
          {Comments, Comment},
          {Galleries, Gallery},
          {Tags, Tag},
          {Posts, Post},
          {Filters, Filter}
        ] do
      Elasticsearch.delete_index!(schema)
      Elasticsearch.create_index!(schema)

      Elasticsearch.reindex(preload(schema, ^context.indexing_preloads()), schema)
    end

    # Reports are a bit special

    Elasticsearch.delete_index!(Report)
    Elasticsearch.create_index!(Report)

    Report
    |> preload([:user, :admin])
    |> Repo.all()
    |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])
    |> Enum.map(&Elasticsearch.index_document(&1, Report))
  end
end
