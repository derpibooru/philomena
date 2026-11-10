defmodule Philomena.UserNameChanges do
  @moduledoc """
  Name change history persistence and staff history auditing.

  `Philomena.Users` manages rename authorization and account mutation, and uses
  this context's transaction step to record the prior name atomically. History
  is retained indefinitely.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Repo
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Users.User

  defp history_query(user_id) do
    UserNameChange
    |> where(user_id: ^user_id)
    |> order_by(desc: :id)
  end

  @doc """
  Records a name change entry for `user` to `multi` under `step`.

  This is a transaction composition function for `Philomena.Users`, not a
  request-facing rename operation. Every successful rename records the exact
  prior spelling, including case-only changes. If any later step in the
  owning transaction fails, the history insert rolls back with it.

  ## Examples

      iex> record_rename(Multi.new(), :name_change, user)
      %Multi{}

  """
  @spec record_rename(Multi.t(), Multi.name(), User.t()) :: Multi.t()
  def record_rename(%Multi{} = multi, step, %User{} = user) do
    changeset = UserNameChange.changeset(%UserNameChange{user_id: user.id}, user.name)

    Multi.insert(multi, step, changeset)
  end

  @doc """
  Returns `user`'s rename history for `actor`, newest first and paginated.

  The collection authorizes `:index` on `UserNameChange`. Forbidden viewers
  receive `{:error, :unauthorized}`.

  ## Examples

      iex> load_history(moderator, user, pagination)
      {:ok, %Scrivener.Page{}}

      iex> load_history(ordinary_user, user, pagination)
      {:error, :unauthorized}

  """
  @spec load_history(Actor.t(), User.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(UserNameChange.t())} | {:error, :unauthorized}
  def load_history(%Actor{} = actor, %User{} = user, pagination) do
    with :ok <- authorize(actor, :index, UserNameChange) do
      {:ok,
       user.id
       |> history_query()
       |> Repo.paginate(pagination)}
    end
  end
end
