defmodule Philomena.TagChanges.Query do
  @moduledoc false

  import Philomena.Authorization, only: [authorize: 3]

  alias PhilomenaQuery.Parse.Parser

  defp user_my_transform(%{user: %{id: id}}, "changes"),
    do: {:ok, %{term: %{true_user_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id tag_count added_tag_count removed_tag_count),
      numeric_fields: ~W(user_id image_id tag_id added_tag_id removed_tag_id),
      date_fields: ~W(created_at),
      literal_fields: ~W(user tag added_tag removed_tag),
      bool_fields: ~W(anonymous),
      default_field: {"tag", :term}
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
      numeric_fields: fields[:numeric_fields] ++ ~W(true_user_id),
      literal_fields: fields[:literal_fields] ++ ~W(true_user fingerprint),
      ip_fields: ~W(ip)
    )
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.new()
    |> Parser.parse(query_string, context)
  end

  def compile(query_string, opts \\ []) do
    user = Keyword.get(opts, :user)

    cond do
      not is_nil(user) and authorize(user, :show, :identity_metadata) == :ok ->
        parse(moderator_fields(), %{user: user}, query_string)

      not is_nil(user) ->
        parse(user_fields(), %{user: user}, query_string)

      true ->
        parse(anonymous_fields(), %{}, query_string)
    end
  end
end
