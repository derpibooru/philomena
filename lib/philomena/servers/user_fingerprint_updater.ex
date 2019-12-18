defmodule Philomena.Servers.UserFingerprintUpdater do
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Repo
  import Ecto.Query

  def child_spec([]) do
    %{
      id: Philomena.Servers.UserFingerprintUpdater,
      start: {Philomena.Servers.UserFingerprintUpdater, :start_link, [[]]}
    }
  end

  def start_link([]) do
    {:ok, spawn_link(&init/0)}
  end

  def cast(user_id, <<"c", _rest::binary>> = fingerprint, updated_at) when byte_size(fingerprint) <= 12 do
    pid = Process.whereis(:fingerprint_updater)
    if pid, do: send(pid, {user_id, fingerprint, updated_at})
  end
  def cast(_user_id, _fingerprint, _updated_at), do: nil

  defp init do
    Process.register(self(), :fingerprint_updater)
    run()
  end

  defp run do
    user_fps = Enum.map(receive_all(), &into_insert_all/1)
    update_query = update(UserFingerprint, inc: [uses: 1], set: [updated_at: fragment("EXCLUDED.updated_at")])

    Repo.insert_all(UserFingerprint, user_fps, on_conflict: update_query, conflict_target: [:user_id, :fingerprint])

    :timer.sleep(:timer.seconds(60))

    run()
  end

  defp receive_all(user_fps \\ %{}) do
    receive do
      {user_id, fingerprint, updated_at} ->
        user_fps
        |> Map.put({user_id, fingerprint}, updated_at)
        |> receive_all()
    after
      0 ->
        user_fps
    end
  end

  defp into_insert_all({{user_id, fingerprint}, updated_at}) do
    %{
      user_id: user_id,
      fingerprint: fingerprint,
      uses: 1,
      created_at: updated_at,
      updated_at: updated_at
    }
  end
end
