defmodule Philomena.Posts.Query do
  alias PhilomenaQuery.Parse.Parser

  defp user_my_transform(%{user: %{id: id}}, "posts"),
    do: {:ok, %{term: %{true_author_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id topic_position),
      numeric_fields: ~W(author_id forum_id topic_id),
      date_fields: ~W(created_at updated_at),
      literal_fields: ~W(author forum),
      ngram_fields: ~W(body subject),
      default_field: {"body", :ngram}
    ]
  end

  defp user_fields do
    fields = anonymous_fields()

    Keyword.merge(fields,
      custom_fields: ~W(my),
      transforms: %{"my" => &user_my_transform/2}
    )
  end

  defp moderator_fields do
    fields = user_fields()

    Keyword.merge(fields,
      numeric_fields: fields[:numeric_fields] ++ ~W(true_author_id deleted_by_user_id),
      literal_fields: fields[:literal_fields] ++ ~W(true_author fingerprint deleted_by_user),
      ngram_fields: fields[:ngram_fields] ++ ~W(deletion_reason),
      ip_fields: ~W(ip),
      bool_fields: ~W(anonymous deleted destroyed_content),
      aliases: %{"deleted" => "hidden_from_users"}
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

      %{role: role} when role in ~W(user assistant) ->
        parse(user_fields(), %{user: user}, query_string)

      %{role: role} when role in ~W(moderator admin) ->
        parse(moderator_fields(), %{user: user}, query_string)

      _ ->
        raise ArgumentError, "Unknown user role."
    end
  end
end
