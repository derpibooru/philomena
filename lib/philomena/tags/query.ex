defmodule Philomena.Tags.Query do
  import Philomena.Search.Parser

  defparser("tag",
    int: ~W(id images),
    literal: ~W(slug name name_in_namespace namespace implies alias_of implied_by aliases category analyzed_name),
    boolean: ~W(aliased),
    ngram: ~W(description short_description),
    aliases: %{
      "implies" => "implied_tags",
      "implied_by" => "implied_by_tags",
      "alias_of" => "aliased_tag"
    },
    default: "analyzed_name"
  )

  def compile(query_string) do
    query_string = query_string || ""

    tag_parser(%{}, query_string)
  end
end
