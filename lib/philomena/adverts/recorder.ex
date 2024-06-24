defmodule Philomena.Adverts.Recorder do
  alias Philomena.Adverts.Advert
  alias Philomena.Repo
  import Ecto.Query

  def run(%{impressions: impressions, clicks: clicks}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create insert statements for Ecto
    impressions = Enum.map(impressions, &impressions_insert_all(&1, now))
    clicks = Enum.map(clicks, &clicks_insert_all(&1, now))

    # Merge into table
    impressions_update = update(Advert, inc: [impressions: fragment("EXCLUDED.impressions")])
    clicks_update = update(Advert, inc: [clicks: fragment("EXCLUDED.clicks")])

    Repo.insert_all(Advert, impressions, on_conflict: impressions_update, conflict_target: [:id])
    Repo.insert_all(Advert, clicks, on_conflict: clicks_update, conflict_target: [:id])

    :ok
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
