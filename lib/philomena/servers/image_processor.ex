defmodule Philomena.Servers.ImageProcessor do
  use GenServer

  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def cast(image_id) do
    pid = Process.whereis(:processor)
    GenServer.cast(pid, {:enqueue, image_id})
  end

  def call do
    pid = Process.whereis(:processor)
    GenServer.call(pid, :wait, :infinity)
  end

  @impl true
  def init([]) do
    Process.register(self(), :processor)
    {:ok, []}
  end

  @impl true
  def handle_cast({:enqueue, image_id}, []) do
    # Ensure that tempfiles get cleaned up by reaping
    # the process after it is done
    Task.async(fn -> process(image_id) end)
    |> Task.await(:infinity)

    {:noreply, []}
  end

  defp process(image_id) do
    Philomena.Processors.process_image(image_id)
  rescue
    _ ->
      nil
  end

  @impl true
  def handle_call(:wait, _from, []) do
    {:reply, nil, []}
  end
end