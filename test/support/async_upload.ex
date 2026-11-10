defmodule Philomena.AsyncUpload do
  @moduledoc """
  Helpers for managing the async image-upload lifecycle from tests.
  """

  @doc """
  Allows supervised image upload tasks to use the current test's sandbox
  connection.
  """
  def allow_async_uploads do
    Ecto.Adapters.SQL.Sandbox.allow(
      Philomena.Repo,
      self(),
      Philomena.ImageUploadSupervisor
    )

    :ok
  end

  @doc """
  Waits for all supervised image upload tasks to exit.
  """
  def await_async_upload do
    for pid <- Task.Supervisor.children(Philomena.ImageUploadSupervisor) do
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        5_000 -> raise "async upload process #{inspect(pid)} did not exit"
      end
    end

    :ok
  end
end
