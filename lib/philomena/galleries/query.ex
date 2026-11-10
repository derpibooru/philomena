defmodule Philomena.Galleries.Query do
  alias PhilomenaQuery.Parse.Parser

  defp user_my_transform(%{user: %{id: id}}, "galleries"),
    do: {:ok, %{term: %{true_creator_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id image_count subscriber_count),
      numeric_fields: ~W(user_id image_ids thumbnail_id),
      literal_fields: ~W(title user),
      date_fields: ~W(created_at updated_at),
      ngram_fields: ~W(description spoiler_warning),
      default_field: {"title", :term},
      aliases: %{
        "user_id" => "creator_id",
        "user" => "creator"
      }
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
      numeric_fields: fields[:numeric_fields] ++ ~W(true_creator_id),
      literal_fields: fields[:literal_fields] ++ ~W(true_creator),
      bool_fields: ~W(anonymous)
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
