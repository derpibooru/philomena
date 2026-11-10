defmodule Philomena.Bans.FingerprintQueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.Bans.Fingerprint
  alias Philomena.Bans.FingerprintQueryForm

  @doc """
  Builds a fingerprint ban query based on the given parameters.

  ## Parameters

    * `bq` - Search fingerprints, ban IDs, reasons, and notes
    * `fingerprint` - Filter by an exact fingerprint

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec build_query(map()) ::
          {:ok, Ecto.Query.t(), FingerprintQueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %FingerprintQueryForm{}
           |> FingerprintQueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        Fingerprint
        |> maybe_filter_bq(query_form)
        |> maybe_filter_fingerprint(query_form)
        |> order_by([fb], desc: fb.created_at, desc: fb.id)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_bq(query, %FingerprintQueryForm{bq: bq}) do
    if bq do
      where(
        query,
        [fb],
        ilike(fb.fingerprint, ^unsanitized_like("%#{bq}%")) or
          fb.generated_ban_id == ^bq or
          fragment("to_tsvector(?) @@ plainto_tsquery(?)", fb.reason, ^bq) or
          fragment("to_tsvector(?) @@ plainto_tsquery(?)", fb.note, ^bq)
      )
    else
      query
    end
  end

  defp maybe_filter_fingerprint(query, %FingerprintQueryForm{fingerprint: fingerprint}) do
    if fingerprint do
      where(query, fingerprint: ^fingerprint)
    else
      query
    end
  end

  defp unsanitized_like(query_string) do
    query_string
  end
end
