defmodule Philomena.Conversations.QueryBuilder do
  @moduledoc false

  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations.Message
  alias Philomena.Conversations.QueryForm
  alias Philomena.Users.User
  import Ecto.Query

  @doc """
  Searches conversations based on the given parameters.

  ## Parameters

    * params - Map of optional search parameters:
      * with - Filter by partner ID

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  def search_conversations(params \\ %{}, %User{} = user) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        user
        |> conversation_index_query()
        |> maybe_filter_partner(user, query_form)
        |> assign_message_count()
        |> apply_sort(user)
        |> apply_preloads()

      {:ok, query, query_form}
    end
  end

  defp conversation_index_query(%User{id: user_id}) do
    Conversation
    |> where(
      [conversation],
      (conversation.from_id == ^user_id and not conversation.from_hidden) or
        (conversation.to_id == ^user_id and not conversation.to_hidden)
    )
  end

  defp maybe_filter_partner(query, %User{id: user_id}, %QueryForm{with: partner_id}) do
    if partner_id do
      where(
        query,
        [conversation],
        (conversation.from_id == ^partner_id and conversation.to_id == ^user_id) or
          (conversation.to_id == ^partner_id and conversation.from_id == ^user_id)
      )
    else
      query
    end
  end

  defp assign_message_count(query) do
    from conversation in query,
      as: :conversation,
      inner_lateral_join:
        count in subquery(
          from message in Message,
            where: message.conversation_id == parent_as(:conversation).id,
            select: %{value: count()}
        ),
      on: true,
      select: %{conversation | message_count: count.value}
  end

  defp apply_sort(query, %User{id: user_id}) do
    unread_predicate =
      dynamic(
        [conversation],
        (conversation.from_id == ^user_id and not conversation.from_read) or
          (conversation.to_id == ^user_id and not conversation.to_read)
      )

    order_by(query, ^[desc: unread_predicate, desc: :last_message_at, desc: :id])
  end

  defp apply_preloads(query) do
    preload(query, [:to, :from])
  end
end
