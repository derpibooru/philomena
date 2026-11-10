defmodule Philomena.Bans.SubnetQueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.Bans.Subnet
  alias Philomena.Bans.SubnetQueryForm

  @doc """
  Builds a subnet ban query based on the given parameters.

  ## Parameters

    * `bq` - Search ban IDs, reasons, and notes
    * `ip` - Filter by subnet bans containing an IP address or CIDR range

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec build_query(map()) ::
          {:ok, Ecto.Query.t(), SubnetQueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %SubnetQueryForm{}
           |> SubnetQueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        Subnet
        |> maybe_filter_bq(query_form)
        |> maybe_filter_ip(query_form)
        |> order_by([sb], desc: sb.created_at, desc: sb.id)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_bq(query, %SubnetQueryForm{bq: bq}) do
    if bq do
      where(
        query,
        [sb],
        sb.generated_ban_id == ^bq or
          fragment("to_tsvector(?) @@ plainto_tsquery(?)", sb.reason, ^bq) or
          fragment("to_tsvector(?) @@ plainto_tsquery(?)", sb.note, ^bq)
      )
    else
      query
    end
  end

  defp maybe_filter_ip(query, %SubnetQueryForm{ip: ip}) do
    if ip do
      where(query, [sb], fragment("? >>= ?", sb.specification, ^ip))
    else
      query
    end
  end
end
