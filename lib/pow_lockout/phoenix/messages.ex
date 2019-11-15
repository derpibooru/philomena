defmodule PowLockout.Phoenix.Messages do
  @moduledoc false

  @doc """
  Flash message to show when account has been unlocked.
  """
  def account_has_been_unlocked(_conn), do: "Account successfully unlocked. You may now log in."

  @doc """
  Flash message to show when account couldn't be unlocked.
  """
  def account_unlock_failed(_conn), do: "Account unlock failed."
end
