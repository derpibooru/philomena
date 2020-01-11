defmodule Philomena.Reports.Query do
  alias Search.Parser

  defp fields do
    [
      int_fields: ~W(id image_id),
      date_fields: ~W(created_at),
      literal_fields:
        ~W(state user user_id admin admin_id reportable_type reportable_id fingerprint),
      ip_fields: ~W(ip),
      bool_fields: ~W(open),
      ngram_fields: ~W(reason),
      default_field: {"reason", :ngram}
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.parser()
    |> Parser.parse(query_string || "", %{})
  end
end
