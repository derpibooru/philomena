defmodule Philomena.Comments.Query do
  alias PhilomenaQuery.Parse.Parser

  defp user_id_transform(_ctx, data) do
    case Integer.parse(data) do
      {int, _rest} ->
        {
          :ok,
          %{
            bool: %{
              must: [
                %{term: %{anonymous: false}},
                %{term: %{user_id: int}}
              ]
            }
          }
        }

      _err ->
        {:error, "Unknown `user_id' value."}
    end
  end

  defp author_transform(_ctx, data) do
    {
      :ok,
      %{
        bool: %{
          must: [
            %{term: %{anonymous: false}},
            %{
              bool: %{
                should: [
                  %{term: %{author: data}},
                  %{wildcard: %{author: data}}
                ]
              }
            }
          ]
        }
      }
    }
  end

  defp user_my_transform(%{user: %{id: id}}, "comments"),
    do: {:ok, %{term: %{user_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id),
      date_fields: ~W(created_at),
      literal_fields: ~W(image_id),
      ngram_fields: ~W(body),
      custom_fields: ~W(author user_id),
      default_field: {"body", :ngram},
      transforms: %{
        "user_id" => &user_id_transform/2,
        "author" => &author_transform/2
      },
      aliases: %{"created_at" => "posted_at"}
    ]
  end

  defp user_fields do
    fields = anonymous_fields()

    Keyword.merge(fields,
      custom_fields: fields[:custom_fields] ++ ~W(my),
      transforms: Map.merge(fields[:transforms], %{"my" => &user_my_transform/2})
    )
  end

  defp moderator_fields do
    fields = user_fields()

    Keyword.merge(fields,
      literal_fields: ~W(image_id user_id author fingerprint),
      ip_fields: ~W(ip),
      bool_fields: ~W(anonymous deleted),
      custom_fields: fields[:custom_fields] -- ~W(author user_id),
      aliases: Map.merge(fields[:aliases], %{"deleted" => "hidden_from_users"}),
      transforms: Map.drop(fields[:transforms], ~W(author user_id))
    )
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.new()
    |> Parser.parse(query_string, context)
  end

  def compile(user, query_string) do
    query_string = query_string || ""

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
