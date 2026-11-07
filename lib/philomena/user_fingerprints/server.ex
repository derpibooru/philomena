defmodule Philomena.UserFingerprints.Server do
  @moduledoc """
  Batches user fingerprint usage updates and submits them to the database every
  60 seconds.
  """

  use GenServer

  alias Philomena.UserFingerprints

  @flush_interval to_timeout(second: 60)

  @doc """
  Starts the user fingerprint usage server.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Asynchronously records usage of a fingerprint by a user.

  Invalid fingerprints return `:error`.

  ## Example

      iex> record_usage(user, "d63c4581f8cf58d", ~U[2024-01-01 00:00:00Z])
      :ok

  """
  @spec record_usage(pos_integer(), term(), DateTime.t()) :: :ok | :error
  def record_usage(user_id, fingerprint, updated_at) do
    if UserFingerprints.valid_format?(fingerprint) do
      GenServer.cast(__MODULE__, {user_id, fingerprint, updated_at})
    else
      :error
    end
  end

  @impl true
  @doc false
  def init(_) do
    schedule_flush()
    {:ok, %{}}
  end

  @impl true
  @doc false
  def handle_cast({user_id, fingerprint, updated_at}, user_fingerprints) do
    {:noreply, Map.put(user_fingerprints, {user_id, fingerprint}, updated_at)}
  end

  @impl true
  @doc false
  def handle_info(:flush, user_fingerprints) do
    UserFingerprints.persist_usage_batch(user_fingerprints)

    schedule_flush()
    {:noreply, %{}}
  end

  defp schedule_flush, do: Process.send_after(self(), :flush, @flush_interval)
end
