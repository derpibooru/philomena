defmodule PowLockout.Ecto.Context do
  @moduledoc """
  Handles lockout context for user.
  """
  alias Pow.{Config, Ecto.Context}
  alias PowLockout.Ecto.Schema

  @doc """
  Finds a user by the `:unlock_token` column.
  """
  @spec get_by_unlock_token(binary(), Config.t()) :: Context.user() | nil
  def get_by_unlock_token(token, config),
    do: Context.get_by([unlock_token: token], config)

  @doc """
  Checks if the user is current locked out.
  """
  @spec locked_out?(Context.user(), Config.t()) :: boolean()
  def locked_out?(%{locked_at: time}, _config) when not is_nil(time),
    do: true

  def locked_out?(_user, _config),
    do: false

  @doc """
  Unlocks the account.

  See `PowLockout.Ecto.Schema.unlock_changeset/1`.
  """
  @spec unlock_account(Context.user(), Config.t()) ::
          {:ok, Context.user()} | {:error, Context.changeset()}
  def unlock_account(user, config) do
    user
    |> Schema.unlock_changeset()
    |> Context.do_update(config)
  end

  @doc """
  Increases the attempts counter and possibly locks the account.

  See `PowLockout.Ecto.Schema.attempt_changeset/1`.
  """
  @spec fail_attempt(Context.user(), Config.t()) ::
          {:ok, Context.user()} | {:error, Context.changeset()}
  def fail_attempt(user, config) do
    user
    |> Schema.attempt_changeset()
    |> Context.do_update(config)
  end

  @doc """
  Sets the attempts counter to zero.

  See `PowLockout.Ecto.Schema.attempt_reset_changeset/1`.
  """
  @spec succeed_attempt(Context.user(), Config.t()) ::
          {:ok, Context.user()} | {:error, Context.changeset()}
  def succeed_attempt(user, config) do
    user
    |> Schema.attempt_reset_changeset()
    |> Context.do_update(config)
  end
end
