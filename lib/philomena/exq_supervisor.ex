defmodule Philomena.ExqSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    child_spec = %{
      id: Exq,
      start: {Exq, :start_link, []}
    }

    Supervisor.init([child_spec], strategy: :one_for_one)
  end
end
