defmodule Mix.Tasks.ConvertToMarkdown do
  use Mix.Task

  import Ecto.Query
  alias Philomena.Repo
  alias Philomena.Batch
  alias PhilomenaWeb.TextileMarkdownRenderer

  @modules [
    {Philomena.Badges.Badge, [:description]},
    {Philomena.Channels.Channel, [:description]},
    {Philomena.Comments.Comment, [:body]},
    {Philomena.Commissions.Commission, [:contact, :information, :will_create, :will_not_create]},
    {Philomena.Commissions.Item, [:description, :add_ons]},
    {Philomena.Conversations.Message, [:body]},
    {Philomena.DnpEntries.DnpEntry, [:conditions, :reason, :instructions]},
    {Philomena.Filters.Filter, [:description]},
    {Philomena.Galleries.Gallery, [:description]},
    {Philomena.Images.Image, [:description]},
    {Philomena.ModNotes.ModNote, [:body]},
    {Philomena.Posts.Post, [:body]},
    {Philomena.Reports.Report, [:report]},
    {Philomena.Tags.Tag, [:description]},
    {Philomena.Users.User, [:description, :scratchpad]},
  ]

  @shortdoc "Rewrites all database rows from Textile to Markdown."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(args) do
    if Mix.env() == :prod and not Enum.member?(args, "--i-know-what-im-doing") do
      raise "do not run this task in production unless you know what you're doing"
    end

    Enum.map(@modules, fn {mod, fields} ->
      Batch.record_batches(mod, fn batch ->
        Enum.map(batch, fn item ->
          updates = Enum.reduce(fields, [], fn field, kwlist ->
            fval = Map.fetch!(item, field)
            [{:"#{field}_md", TextileMarkdownRenderer.render_one(%{body: fval})} | kwlist]
          end)

          (mod
          |> where(id: ^item.id)
          |> Repo.update_all(set: updates))

          IO.write("\r#{mod}\t#{item.id}\t")
        end)
      end)

      IO.puts("")
    end)
  end
end
