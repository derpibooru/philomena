defmodule Philomena.Tags.Query do
  alias Search.Parser

  int_fields     = ~W(id images)
  literal_fields = ~W(slug name name_in_namespace namespace implies alias_of implied_by aliases category analyzed_name)
  bool_fields    = ~W(aliased)
  ngram_fields   = ~W(description short_description)
  default_field  = "analyzed_name"
  aliases        = %{
    "implies" => "implied_tags",
    "implied_by" => "implied_by_tags",
    "alias_of" => "aliased_tag"
  }

  @tag_parser Parser.parser(
    int_fields: int_fields,
    literal_fields: literal_fields,
    bool_fields: bool_fields,
    ngram_fields: ngram_fields,
    default_field: default_field,
    aliases: aliases
  )

  def compile(query_string) do
    query_string = query_string || ""

    Parser.parse(@tag_parser, query_string)
  end
end
