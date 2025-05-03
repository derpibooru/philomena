defmodule Philomena.Galleries.Query do
  alias PhilomenaQuery.Parse.Parser

  defp fields do
    [
      int_fields: ~W(id image_count watcher_count),
      numeric_fields: ~W(image_ids watcher_ids),
      literal_fields: ~W(title user),
      date_fields: ~W(created_at updated_at),
      ngram_fields: ~W(description),
      default_field: {"title", :term},
      aliases: %{
        "user" => "creator"
      }
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.new()
    |> Parser.parse(query_string)
  end
end
