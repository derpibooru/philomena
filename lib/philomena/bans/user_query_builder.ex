defmodule Philomena.Bans.UserQueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.Bans.User
  alias Philomena.Bans.UserQueryForm

  @doc """
  Builds a user ban query based on the given parameters.

  ## Parameters

    * `bq` - Search banned-user names, ban IDs, reasons, and notes
    * `user_id` - Filter by an exact banned-user ID

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec build_query(map()) ::
          {:ok, Ecto.Query.t(), UserQueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %UserQueryForm{}
           |> UserQueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        User
        |> maybe_filter_bq(query_form)
        |> maybe_filter_user(query_form)
        |> order_by([ub], desc: ub.created_at, desc: ub.id)

      {:ok, query, query_form}
    end
  end

  defp maybe_filter_bq(query, %UserQueryForm{bq: bq}) do
    if bq do
      like_bq = "%#{bq}%"

      query
      |> join(:inner, [ub], _ in assoc(ub, :user))
      |> where(
        [ub, u],
        ilike(u.name, ^like_bq) or
          ub.generated_ban_id == ^bq or
          fragment("to_tsvector(?) @@ plainto_tsquery(?)", ub.reason, ^bq) or
          fragment("to_tsvector(?) @@ plainto_tsquery(?)", ub.note, ^bq)
      )
    else
      query
    end
  end

  defp maybe_filter_user(query, %UserQueryForm{user_id: user_id}) do
    if user_id do
      where(query, user_id: ^user_id)
    else
      query
    end
  end
end
