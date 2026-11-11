defmodule PhilomenaQuery.Parse.ParserTest do
  use ExUnit.Case, async: true

  alias PhilomenaQuery.Parse.Parser

  test "referenced terms exclude negated clauses and their descendants" do
    query = %{
      bool: %{
        must: [%{term: %{"tags" => "cute"}}],
        must_not: %{
          bool: %{
            should: [%{term: %{"tags" => "safe"}}],
            must_not: %{term: %{"tags" => "solo"}}
          }
        }
      }
    }

    assert Parser.referenced_term_values(query, "tags") == ["cute"]

    assert Parser.referenced_term_values(
             %{bool: %{must_not: %{term: %{"tags" => "safe"}}}},
             "tags"
           ) == []
  end
end
