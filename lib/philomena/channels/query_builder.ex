defmodule Philomena.Channels.QueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.Channels.Channel
  alias Philomena.Channels.QueryForm

  @doc """
  Builds a channel query based on the given parameters.

  ## Parameters

    * `cq` - Search channel titles and short names by prefix, or artist tag
      names by substring

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
      query = Channel |> maybe_search(query_form)

      {:ok, query, query_form}
    end
  end

  defp maybe_search(query, %QueryForm{cq: cq}) do
    if cq do
      title_query = "#{like_sanitize(cq)}%"
      tag_query = "%#{like_sanitize(cq)}%"

      from channel in query,
        left_join: tag in assoc(channel, :associated_artist_tag),
        where:
          ilike(channel.title, ^title_query) or ilike(channel.short_name, ^title_query) or
            ilike(tag.name, ^tag_query)
    else
      query
    end
  end

  defp like_sanitize(input) do
    String.replace(input, ["\\", "%", "_"], &<<"\\", &1>>)
  end
end
