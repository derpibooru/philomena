defmodule Philomena.Servers.UserIpUpdater do
  alias Philomena.UserIps.UserIp
  alias Philomena.Repo
  import Ecto.Query

  def child_spec([]) do
    %{
      id: Philomena.Servers.UserIpUpdater,
      start: {Philomena.Servers.UserIpUpdater, :start_link, [[]]}
    }
  end

  def start_link([]) do
    {:ok, spawn_link(&init/0)}
  end

  def cast(user_id, ip_address, updated_at) do
    pid = Process.whereis(:ip_updater)
    if pid, do: send(pid, {user_id, ip_address, updated_at})
  end

  defp init do
    Process.register(self(), :ip_updater)
    run()
  end

  defp run do
    user_ips = Enum.map(receive_all(), &into_insert_all/1)

    update_query =
      update(UserIp, inc: [uses: 1], set: [updated_at: fragment("EXCLUDED.updated_at")])

    Repo.insert_all(UserIp, user_ips, on_conflict: update_query, conflict_target: [:user_id, :ip])

    :timer.sleep(:timer.seconds(60))

    run()
  end

  defp receive_all(user_ips \\ %{}) do
    receive do
      {user_id, ip_address, updated_at} ->
        user_ips
        |> Map.put({user_id, ip_address}, updated_at)
        |> receive_all()
    after
      0 ->
        user_ips
    end
  end

  defp into_insert_all({{user_id, ip_address}, updated_at}) do
    %{
      user_id: user_id,
      ip: cast_ip(ip_address),
      uses: 1,
      created_at: updated_at,
      updated_at: updated_at
    }
  end

  # There exists no EctoNetwork.INET.cast!/1
  defp cast_ip(ip), do: elem(EctoNetwork.INET.cast(ip), 1)
end
