defmodule Philomena.Reports.Query do
  alias Search.Parser

  int_fields         = ~W(id image_id)
  date_fields        = ~W(created_at)
  literal_fields     = ~W(state user user_id admin admin_id reportable_type reportable_id fingerprint)
  ip_fields          = ~W(ip)
  bool_fields        = ~W(open)
  ngram_fields       = ~W(reason)
  default_field      = "reason"

  @parser Parser.parser(
    int_fields: int_fields,
    date_fields: date_fields,
    literal_fields: literal_fields,
    ip_fields: ip_fields,
    bool_fields: bool_fields,
    ngram_fields: ngram_fields,
    default_field: default_field
  )

  def compile(query_string) do
    Parser.parse(@parser, query_string || "", %{})
  end
end
