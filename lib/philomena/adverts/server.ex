defmodule Philomena.Adverts.Server do
  @moduledoc """
  Advert impression and click aggregator.

  Updating the impression count for adverts and clicks on every pageload is unnecessary
  and slows down requests. This module collects the adverts and clicks and submits a batch
  of updates to the database after every 10 seconds asynchronously, reducing the amount of
  work to be done.
  """

  use GenServer
  alias Philomena.Adverts.Recorder

  @type advert_id :: integer()

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
  @spec record_impression(advert_id()) :: :ok
  def record_impression(advert_id) do
    GenServer.cast(__MODULE__, {:impressions, advert_id})
  end

  @doc """
  Asynchronously records a new click.

  ## Example

      iex> record_click(advert.id)
      :ok

  """
  @spec record_click(advert_id()) :: :ok
  def record_click(advert_id) do
    GenServer.cast(__MODULE__, {:clicks, advert_id})
  end

  # Used to force the GenServer to immediately sleep when no
  # messages are available.
  @timeout 0
  @sleep :timer.seconds(10)

  @impl true
  @doc false
  def init(_) do
    {:ok, initial_state(), @timeout}
  end

  @impl true
  @doc false
  def handle_cast({type, advert_id}, state) do
    # Update the counter described by the message
    state = update_in(state[type], &increment_counter(&1, advert_id))

    # Return to GenServer event loop
    {:noreply, state, @timeout}
  end

  @impl true
  @doc false
  def handle_info(:timeout, state) do
    # Process all updates from state now
    Recorder.run(state)

    # Sleep for the specified delay
    :timer.sleep(@sleep)

    # Return to GenServer event loop
    {:noreply, initial_state(), @timeout}
  end

  defp increment_counter(map, advert_id) do
    Map.update(map, advert_id, 1, &(&1 + 1))
  end

  defp initial_state do
    %{impressions: %{}, clicks: %{}}
  end
end
