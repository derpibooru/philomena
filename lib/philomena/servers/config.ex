defmodule Philomena.Servers.Config do
  use GenServer

  @process_name :philomena_config

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def get(key) do
    pid = Process.whereis(@process_name)
    GenServer.call(pid, {:get, key})
  end

  def reload do
    pid = Process.whereis(@process_name)
    GenServer.cast(pid, :reload)
  end

  @impl true
  def init([]) do
    Process.register(self(), @process_name)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    state = maybe_update_state(state, key, Map.has_key?(state, key))

    {:reply, state[key], state}
  end

  @impl true
  def handle_cast(:reload, _state) do
    {:noreply, %{}}
  end

  @impl true
  def code_change(_old_vsn, _state, _extra) do
    {:ok, %{}}
  end

  defp maybe_update_state(state, key, false) do
    Map.put(state, key, load_config(key))
  end
  defp maybe_update_state(state, _key, _true), do: state

  defp load_config(name) do
    with {:ok, text} <- File.read("config/#{name}.json"),
         {:ok, json} <- Jason.decode(text)
    do
      json
    end
  end
end
