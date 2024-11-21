defmodule Philomena.Markdown.SubscriptMigrator do
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Item, as: CommissionItem
  alias Philomena.Commissions.Commission
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Images.Image
  alias Philomena.Conversations.Message
  alias Philomena.ModNotes.ModNote
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  import Ecto.Query
  alias PhilomenaQuery.Batch
  alias Philomena.Markdown
  alias Philomena.Repo

  @types %{
    comments: {Comment, [:body]},
    commission_items: {CommissionItem, [:description, :add_ons]},
    commissions: {Commission, [:information, :contact, :will_create, :will_not_create]},
    dnp_entries: {DnpEntry, [:conditions, :reason, :instructions]},
    images: {Image, [:description, :scratchpad]},
    messages: {Message, [:body]},
    mod_notes: {ModNote, [:body]},
    posts: {Post, [:body]},
    reports: {Report, [:reason]},
    tags: {Tag, [:description]},
    users: {User, [:description, :scratchpad]}
  }

  @doc """
  Format the ranged Markdown documents to their canonical CommonMark form.
  """
  @spec migrate(type :: :all | atom(), id_start :: non_neg_integer(), id_end :: non_neg_integer()) ::
          :ok
  def migrate(type, id_start, id_end)

  def migrate(:all, _id_start, _id_end) do
    Enum.each(@types, fn {name, _schema_columns} ->
      migrate(name, 0, 2_147_483_647)
    end)
  end

  def migrate(type, id_start, id_end) do
    IO.puts("#{type}:")

    {schema, columns} = Map.fetch!(@types, type)

    schema
    |> where([s], s.id >= ^id_start and s.id < ^id_end)
    |> Batch.records()
    |> Enum.each(fn s ->
      case generate_updates(s, columns) do
        [] ->
          :ok

        updates ->
          IO.write("\r#{s.id}")

          {1, nil} =
            schema
            |> where(id: ^s.id)
            |> Repo.update_all(set: updates)
      end
    end)
  end

  @spec generate_updates(s :: struct(), columns :: [atom()]) :: Keyword.t()
  defp generate_updates(s, columns) do
    Enum.flat_map(columns, fn col ->
      with value when not is_nil(value) <- Map.fetch!(s, col),
           true <- Markdown.has_subscript?(value) do
        [{col, Markdown.to_cm(value)}]
      else
        _ ->
          []
      end
    end)
  end
end
