defmodule Philomena.Galleries.Query do
  alias Search.Parser

  int_fields     = ~W(id image_count watcher_count)
  literal_fields = ~W(title user image_ids watcher_ids)
  date_fields    = ~W(created_at updated_at)
  ngram_fields   = ~W(description)
  default_field  = "title"
  aliases        = %{
    "user" => "creator"
  }

  @gallery_parser Parser.parser(
    int_fields: int_fields,
    literal_fields: literal_fields,
    date_fields: date_fields,
    ngram_fields: ngram_fields,
    default_field: default_field,
    aliases: aliases
  )

  def compile(query_string) do
    query_string = query_string || ""

    Parser.parse(@gallery_parser, query_string)
  end
end
