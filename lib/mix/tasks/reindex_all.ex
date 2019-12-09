defmodule Mix.Tasks.ReindexAll do
  use Mix.Task

  alias Philomena.{Comments.Comment, Galleries.Gallery, Posts.Post, Images.Image, Reports.Report, Tags.Tag}
  alias Philomena.{Comments, Galleries, Posts, Images, Tags}
  alias Philomena.Polymorphic
  alias Philomena.Repo
  import Ecto.Query

  @shortdoc "Destroys and recreates all Elasticsearch indices."
  def run(_) do
    if Mix.env == "prod" do
      raise "do not run this task in production"
    end

    {:ok, _apps} = Application.ensure_all_started(:philomena)

    for {context, schema} <- [{Images, Image}, {Comments, Comment}, {Galleries, Gallery}, {Tags, Tag}, {Posts, Post}] do
      schema.delete_index!
      schema.create_index!

      schema.reindex(schema |> preload(^context.indexing_preloads()))
    end

    # Reports are a bit special

    Report.delete_index!
    Report.create_index!

    Report
    |> preload([:user, :admin])
    |> Repo.all()
    |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])
    |> Enum.map(&Report.index_document/1)
  end
end