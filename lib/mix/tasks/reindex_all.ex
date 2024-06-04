defmodule Mix.Tasks.ReindexAll do
  use Mix.Task

  alias PhilomenaQuery.Search

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

  @indices [
    {Images, Image},
    {Comments, Comment},
    {Galleries, Gallery},
    {Tags, Tag},
    {Posts, Post},
    {Filters, Filter}
  ]

  @shortdoc "Destroys and recreates all OpenSearch indices."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(args) do
    if Mix.env() == :prod and not Enum.member?(args, "--i-know-what-im-doing") do
      raise "do not run this task unless you know what you're doing"
    end

    @indices
    |> Enum.map(fn {context, schema} ->
      Task.async(fn ->
        Search.delete_index!(schema)
        Search.create_index!(schema)

        Search.reindex(preload(schema, ^context.indexing_preloads()), schema)
      end)
    end)
    |> Task.await_many(:infinity)

    # Reports are a bit special

    Search.delete_index!(Report)
    Search.create_index!(Report)

    Report
    |> preload([:user, :admin])
    |> Repo.all()
    |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])
    |> Enum.map(&Search.index_document(&1, Report))
  end
end
