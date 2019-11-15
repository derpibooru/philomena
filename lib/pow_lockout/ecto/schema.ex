defmodule PowLockout.Ecto.Schema do
  @moduledoc """
  Handles the lockout schema for user.

  ## Customize PowLockout fields

  If you need to modify any of the fields that `PowLockout` adds to
  the user schema, you can override them by defining them before
  `pow_user_fields/0`:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema
        use Pow.Extension.Ecto.Schema,
          extensions: [PowLockout]

        schema "users" do
          field :unlock_token, :string
          field :locked_at, :utc_datetime
          field :failed_attempts, :integer

          pow_user_fields()

          timestamps()
        end
      end
  """

  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset
  alias Pow.UUID

  @doc false
  @impl true
  def attrs(_config) do
    [
      {:unlock_token, :string},
      {:locked_at, :utc_datetime},
      {:failed_attempts, :integer}
    ]
  end

  @doc false
  @impl true
  def indexes(_config) do
    [{:unlock_token, true}]
  end

  @doc """
  Sets the account as unlocked.

  This sets `:locked_at` and `:unlock_token` to nil, and sets
  `failed_attempts` to 0.
  """
  @spec unlock_changeset(Ecto.Schema.t() | Changeset.t()) :: Changeset.t()
  def unlock_changeset(user_or_changeset) do
    changes =
      [
        locked_at: nil,
        unlock_token: nil,
        failed_attempts: 0
      ]

    user_or_changeset
    |> Changeset.change(changes)
  end

  @doc """
  Sets the account as locked.

  This sets `:locked_at` to now and sets `:unlock_token` to a random UUID.
  """
  @spec lock_changeset(Ecto.Schema.t() | Changeset.t()) :: Changeset.t()
  def lock_changeset(user_or_changeset) do
    changeset = Changeset.change(user_or_changeset)
    locked_at = Pow.Ecto.Schema.__timestamp_for__(changeset.data.__struct__, :locked_at)
    changes =
      [
        locked_at: locked_at,
        unlock_token: UUID.generate()
      ]

    changeset
    |> Changeset.change(changes)
  end

  @doc """
  Updates the failed attempt count.

  This increments `:failed_attempts` by 1, or sets it to 1 if it is nil.
  The first time it becomes greater than 10, it also locks the user.
  """
  @spec attempt_changeset(Ecto.Schema.t() | Changeset.t()) :: Changeset.t()
  def attempt_changeset(%Changeset{data: %{failed_attempts: attempts}} = changeset) when is_integer(attempts) and attempts < 10 do
    Changeset.change(changeset, failed_attempts: attempts + 1)
  end
  def attempt_changeset(%Changeset{data: %{failed_attempts: attempts, locked_at: nil}} = changeset) when is_integer(attempts) do
    lock_changeset(changeset)
  end
  def attempt_changeset(%Changeset{data: %{failed_attempts: attempts, locked_at: _locked_at}} = changeset) when is_integer(attempts) do
    changeset
  end
  def attempt_changeset(%Changeset{} = changeset) do
    Changeset.change(changeset, failed_attempts: 1)
  end

  def attempt_changeset(user) do
    user
    |> Changeset.change()
    |> attempt_changeset()
  end

  @doc """
  Resets the failed attempt count.

  This sets `:failed_attempts` to 0.
  """
  @spec attempt_reset_changeset(Ecto.Schema.t() | Changeset.t()) :: Changeset.t()
  def attempt_reset_changeset(user_or_changeset) do
    user_or_changeset
    |> Changeset.change(failed_attempts: 0)
  end
end
