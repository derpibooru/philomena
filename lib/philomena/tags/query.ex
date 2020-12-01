defmodule Philomena.Tags.Query do
  alias Philomena.Search.Parser

  defp fields do
    [
      int_fields: ~W(id images),
      literal_fields:
        ~W(slug name name_in_namespace namespace implies alias_of implied_by aliases category analyzed_name),
      bool_fields: ~W(aliased),
      ngram_fields: ~W(description short_description),
      default_field: {"name", :term},
      aliases: %{
        "implies" => "implied_tags",
        "implied_by" => "implied_by_tags",
        "alias_of" => "aliased_tag"
      }
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.parser()
    |> Parser.parse(query_string || "")
  end
end
