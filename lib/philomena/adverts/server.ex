defmodule Philomena.Adverts.Server do
  @moduledoc """
  Batches advert click and impression updates and submits them to the database
  every 10 seconds.
  """

  use GenServer
  alias Philomena.Adverts

  @flush_interval to_timeout(second: 10)

  @doc """
  Starts the GenServer.

  See `GenServer.start_link/2` for more information.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Asynchronously records a new impression.

  ## Example

      iex> record_impression(advert.id)
      :ok

  """
  @spec record_impression(integer()) :: :ok
  def record_impression(advert_id) do
    GenServer.cast(__MODULE__, {:impressions, advert_id})
  end

  @doc """
  Asynchronously records a new click.

  ## Example

      iex> record_click(advert.id)
      :ok

  """
  @spec record_click(integer()) :: :ok
  def record_click(advert_id) do
    GenServer.cast(__MODULE__, {:clicks, advert_id})
  end

  @impl true
  @doc false
  def init(_) do
    schedule_flush()
    {:ok, initial_state()}
  end

  @impl true
  @doc false
  def handle_cast({type, advert_id}, state) do
    # Update the counter described by the message
    {:noreply, update_in(state[type], &increment_counter(&1, advert_id))}
  end

  @impl true
  @doc false
  def handle_info(:flush, state) do
    Adverts.record_counters(state)

    schedule_flush()
    {:noreply, initial_state()}
  end

  defp schedule_flush, do: Process.send_after(self(), :flush, @flush_interval)

  defp increment_counter(map, advert_id) do
    Map.update(map, advert_id, 1, &(&1 + 1))
  end

  defp initial_state do
    %{impressions: %{}, clicks: %{}}
  end
end
