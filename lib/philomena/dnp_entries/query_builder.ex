defmodule Philomena.DnpEntries.QueryBuilder do
  @moduledoc false

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.DnpEntries.QueryForm
  import Ecto.Query

  @doc """
  Searches DNP entries based on the given parameters.

  ## Parameters

    * params - Map of optional search parameters:
      * states - Filter by entry states
      * text - Search requesting users, tags, reasons, conditions, and instructions

  When neither filter is present, only active DNP entries are returned.

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec search_dnp_entries(map()) ::
          {:ok, Ecto.Query.t(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def search_dnp_entries(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        DnpEntry
        |> maybe_filter_states(query_form)
        |> maybe_filter_text(query_form)
        |> preload([:tag, :requesting_user, :modifying_user])
        |> order_by(desc: :updated_at)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_states(query, %QueryForm{states: []}), do: query

  defp maybe_filter_states(query, %QueryForm{states: states}) do
    where(query, [d], d.aasm_state in ^states)
  end

  defp maybe_filter_text(query, %QueryForm{text: text}) do
    if text do
      pattern = "%#{unsanitized_like(text)}%"

      query
      |> join(:inner, [d], _ in assoc(d, :tag))
      |> join(:inner, [d, _t], _ in assoc(d, :requesting_user))
      |> where(
        [d, t, u],
        ilike(u.name, ^pattern) or ilike(t.name, ^pattern) or ilike(d.reason, ^pattern) or
          ilike(d.conditions, ^pattern) or ilike(d.instructions, ^pattern)
      )
    else
      query
    end
  end

  defp unsanitized_like(query_string) do
    query_string
  end
end
