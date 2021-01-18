defmodule PhilomenaWeb.AdvertUpdater do
  alias Philomena.Adverts.Advert
  alias Philomena.Repo
  import Ecto.Query

  def child_spec([]) do
    %{
      id: PhilomenaWeb.AdvertUpdater,
      start: {PhilomenaWeb.AdvertUpdater, :start_link, [[]]}
    }
  end

  def start_link([]) do
    {:ok, spawn_link(&init/0)}
  end

  def cast(type, advert_id) when type in [:impression, :click] do
    pid = Process.whereis(:advert_updater)
    if pid, do: send(pid, {type, advert_id})
  end

  defp init do
    Process.register(self(), :advert_updater)
    run()
  end

  defp run do
    # Read impression counts from mailbox
    {impressions, clicks} = receive_all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create insert statements for Ecto
    impressions = Enum.map(impressions, &impressions_insert_all(&1, now))
    clicks = Enum.map(clicks, &clicks_insert_all(&1, now))

    # Merge into table
    impressions_update = update(Advert, inc: [impressions: fragment("EXCLUDED.impressions")])
    clicks_update = update(Advert, inc: [clicks: fragment("EXCLUDED.clicks")])

    Repo.insert_all(Advert, impressions, on_conflict: impressions_update, conflict_target: [:id])
    Repo.insert_all(Advert, clicks, on_conflict: clicks_update, conflict_target: [:id])

    :timer.sleep(:timer.seconds(10))

    run()
  end

  defp receive_all(impressions \\ %{}, clicks \\ %{}) do
    receive do
      {:impression, advert_id} ->
        impressions = Map.update(impressions, advert_id, 1, &(&1 + 1))
        receive_all(impressions, clicks)

      {:click, advert_id} ->
        clicks = Map.update(clicks, advert_id, 1, &(&1 + 1))
        receive_all(impressions, clicks)
    after
      0 ->
        {impressions, clicks}
    end
  end

  defp impressions_insert_all({advert_id, impressions}, now) do
    %{
      id: advert_id,
      impressions: impressions,
      created_at: now,
      updated_at: now
    }
  end

  defp clicks_insert_all({advert_id, clicks}, now) do
    %{
      id: advert_id,
      clicks: clicks,
      created_at: now,
      updated_at: now
    }
  end
end
