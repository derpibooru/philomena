defmodule Philomena.Filters.Visibility do
  @moduledoc """
  OpenSearch query scopes for filter searches.

  These scopes intentionally mirror the `:show` rules in
  `Philomena.Users.Ability`.
  """

  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Attribution.Actor
  alias Philomena.Filters.Filter

  defp user_visibility_filters(nil),
    do: []

  defp user_visibility_filters(user),
    do: [%{term: %{user_id: user.id}}]

  @doc """
  Generates an OpenSearch boolean `filter` clause to select filters visible to
  `actor`.

  Moderators and administrators may see private filters. Users may see public
  filters and non-anonymous users may also see their own filters.

  ## Examples

      iex> query_filters(admin_actor)
      []

      iex> query_filters(actor)
      [%{term: %{public: true}}, ...]

  """
  def search_filters(%Actor{user: user} = actor) do
    case authorize(actor, :search_all, Filter) do
      :ok ->
        []

      {:error, :unauthorized} ->
        %{
          bool: %{
            should: [
              %{term: %{public: true}},
              %{term: %{system: true}}
              | user_visibility_filters(user)
            ]
          }
        }
    end
  end
end
