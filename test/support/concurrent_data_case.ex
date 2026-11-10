defmodule Philomena.ConcurrentDataCase do
  @moduledoc """
  Test case and helpers for tests that deliberately run database operations in
  parallel.

  Concurrent tests use a shared SQL sandbox connection so their worker tasks
  can participate in the same test transaction. Ordinary data tests should use
  `Philomena.DataCase` instead.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Philomena.DataCase, async: false
      import Philomena.ConcurrentDataCase
    end
  end

  @doc """
  Runs zero-argument functions concurrently, releasing all workers together.

  Each worker is explicitly allowed to use the test process's sandbox
  connection before any worker is released.
  """
  def concurrently(functions, timeout \\ 10_000) when is_list(functions) do
    parent = self()

    tasks =
      Enum.map(functions, fn function ->
        task =
          Task.async(fn ->
            receive do
              :go -> function.()
            end
          end)

        Ecto.Adapters.SQL.Sandbox.allow(Philomena.Repo, parent, task.pid)
        task
      end)

    Enum.each(tasks, &send(&1.pid, :go))
    Enum.map(tasks, &Task.await(&1, timeout))
  end
end
