defmodule Philomena.Reports.Query do
  alias PhilomenaQuery.Parse.Parser

  defp fields do
    [
      int_fields: ~W(id),
      numeric_fields: ~W(user_id admin_id reportable_id image_id),
      date_fields: ~W(created_at),
      literal_fields: ~W(state user admin reportable_type fingerprint),
      ip_fields: ~W(ip),
      bool_fields: ~W(open),
      ngram_fields: ~W(reason),
      default_field: {"reason", :ngram},
      no_downcase_fields: ~W(reportable_type)
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.new()
    |> Parser.parse(query_string, %{})
  end
end
