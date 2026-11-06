defmodule Philomena.Comments.Query do
  @moduledoc """
  Compiles the user-facing comment search language.
  """

  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Attribution.Actor
  alias Philomena.Comments.Comment
  alias PhilomenaQuery.Parse.Parser
  alias Philomena.Tags.Tag

  defp user_my_transform(%{user: %{id: id}}, "comments"),
    do: {:ok, %{term: %{true_author_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id),
      numeric_fields: ~W(author_id image_id),
      date_fields: ~W(created_at updated_at),
      literal_fields: ~W(author image.tags),
      ngram_fields: ~W(body),
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
      bool_fields: ~W(anonymous deleted image.deleted approved image.approved),
      aliases: %{
        "deleted" => "hidden_from_users",
        "image.deleted" => "image.hidden_from_users"
      },
      normalizations: %{"image.tags" => &Tag.clean_tag_name/1}
    )
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.new()
    |> Parser.parse(query_string, context)
  end

  defp fields_for(nil), do: anonymous_fields()

  defp fields_for(%Actor{} = actor) do
    case authorize(actor, :search_sensitive, Comment) do
      :ok -> moderator_fields()
      {:error, :unauthorized} -> user_fields()
    end
  end

  @doc """
  Compiles `query_string` using the fields available to `opts[:actor]`.

  Anonymous callers receive public fields, signed-in callers receive the `my`
  transform, and actors authorized for sensitive comment search receive
  moderation metadata fields as well.

  ## Examples

      iex> compile("body:hello", actor: actor)
      {:ok, %{match: %{body: %{query: "hello", analyzer: "fulltext_analyzer"}}}}

      iex> compile("ip:192.0.2.1", actor: moderator_actor)
      {:ok, %{term: %{ip: "192.0.2.1"}}}

  """
  @spec compile(String.t() | nil, keyword()) :: {:ok, map()} | {:error, String.t()}
  def compile(query_string, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    user = if actor, do: actor.user

    actor
    |> fields_for()
    |> parse(%{user: user}, query_string)
  end
end
