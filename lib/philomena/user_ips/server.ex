defmodule Philomena.UserIps.Server do
  @moduledoc """
  Batches user IP usage updates and submits them to the database every 60 seconds.
  """

  use GenServer

  alias Philomena.UserIps

  @flush_interval to_timeout(second: 60)

  @doc """
  Starts the user IP usage server.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Asynchronously records usage of an IP address by a user.

  Invalid IP addresses return `:error`.

  ## Example

      iex> record_usage(user, {127, 0, 0, 1}, ~U[2024-01-01 00:00:00Z])
      :ok

  """
  @spec record_usage(pos_integer(), term(), DateTime.t()) :: :ok | :error
  def record_usage(user_id, ip_address, updated_at) do
    with {:ok, ip_address} <- EctoNetwork.INET.cast(ip_address) do
      GenServer.cast(__MODULE__, {user_id, ip_address, updated_at})
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
  def handle_cast({user_id, ip_address, updated_at}, user_ips) do
    {:noreply, Map.put(user_ips, {user_id, ip_address}, updated_at)}
  end

  @impl true
  @doc false
  def handle_info(:flush, user_ips) do
    UserIps.persist_usage_batch(user_ips)

    schedule_flush()
    {:noreply, %{}}
  end

  defp schedule_flush, do: Process.send_after(self(), :flush, @flush_interval)
end
