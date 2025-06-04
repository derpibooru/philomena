defmodule Philomena.Filters.Query do
  alias PhilomenaQuery.Parse.Parser

  defp user_my_transform(%{user: %{id: id}}, "filters"),
    do: {:ok, %{term: %{user_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id spoilered_count hidden_count),
      numeric_fields: ~W(user_id),
      date_fields: ~W(created_at),
      ngram_fields: ~W(description),
      literal_fields: ~W(name creator),
      bool_fields: ~W(public system),
      default_field: {"name", :term}
    ]
  end

  defp user_fields do
    fields = anonymous_fields()

    Keyword.merge(fields,
      custom_fields: ~W(my),
      transforms: %{"my" => &user_my_transform/2}
    )
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.new()
    |> Parser.parse(query_string, context)
  end

  def compile(query_string, opts \\ []) do
    user = Keyword.get(opts, :user)

    case user do
      nil ->
        parse(anonymous_fields(), %{user: nil}, query_string)

      user ->
        parse(user_fields(), %{user: user}, query_string)
    end
  end
end
