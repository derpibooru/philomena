defmodule Philomena.ArtistLinks.QueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.ArtistLinks.QueryForm

  @doc """
  Builds an artist link query based on the given parameters.

  ## Parameters

    * `states` - Filter by artist-link states; an empty list includes every state
    * `text` - Search profile user names and link URIs

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec build_query(map()) :: {:ok, Ecto.Query.t(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        ArtistLink
        |> maybe_filter_states(query_form)
        |> maybe_filter_text(query_form)
        |> order_by([artist_link], desc: artist_link.created_at, desc: artist_link.id)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_states(query, %QueryForm{states: []}), do: query

  defp maybe_filter_states(query, %QueryForm{states: states}) do
    where(query, [artist_link], artist_link.aasm_state in ^states)
  end

  defp maybe_filter_text(query, %QueryForm{text: text}) do
    if text do
      pattern = "%#{unsanitized_like(text)}%"

      query
      |> join(:inner, [artist_link], user in assoc(artist_link, :user))
      |> where(
        [artist_link, user],
        ilike(user.name, ^pattern) or ilike(artist_link.uri, ^pattern)
      )
    else
      query
    end
  end

  defp unsanitized_like(query_string) do
    query_string
  end
end
