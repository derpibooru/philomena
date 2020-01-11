defmodule PowLockout.Plug do
  @moduledoc """
  Plug helper methods.
  """
  alias Plug.Conn
  alias Pow.Plug
  alias PowLockout.Ecto.Context
  require IEx

  @doc """
  Check if the current user is locked out.
  """
  @spec locked_out?(Conn.t()) :: boolean()
  def locked_out?(conn) do
    config = Plug.fetch_config(conn)

    conn
    |> Plug.current_user()
    |> Context.locked_out?(config)
  end

  @doc """
  Get the user belonging to the id field.
  """
  @spec user_for_attempts(Conn.t()) :: map() | nil
  def user_for_attempts(conn) do
    config = Plug.fetch_config(conn)
    id_field = Pow.Ecto.Schema.user_id_field(config)
    id_value = to_string(conn.params["user"][to_string(id_field)])

    Pow.Ecto.Context.get_by([{id_field, id_value}], config)
  end

  @doc """
  Unlocks the user found by the provided unlock token.
  """
  @spec unlock_account(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def unlock_account(conn, token) do
    config = Plug.fetch_config(conn)

    token
    |> Context.get_by_unlock_token(config)
    |> maybe_unlock_account(conn, config)
  end

  defp maybe_unlock_account(nil, conn, _config) do
    {:error, nil, conn}
  end

  defp maybe_unlock_account(user, conn, config) do
    user
    |> Context.unlock_account(config)
    |> case do
      {:error, changeset} -> {:error, changeset, conn}
      {:ok, user} -> {:ok, user, conn}
    end
  end

  @doc """
  Increments the failed attempts counter and possibly locks the user out.
  """
  @spec fail_attempt(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def fail_attempt(conn, user) do
    config = Plug.fetch_config(conn)

    Context.fail_attempt(user, config)
    |> case do
      {:error, changeset} -> {:error, changeset, conn}
      {:ok, user} -> {:ok, user, conn}
    end
  end

  @doc """
  Resets the failed attempts counter to 0.
  """
  @spec succeed_attempt(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def succeed_attempt(conn, user) do
    config = Plug.fetch_config(conn)

    Context.succeed_attempt(user, config)
    |> case do
      {:error, changeset} -> {:error, changeset, conn}
      {:ok, user} -> {:ok, user, conn}
    end
  end
end
