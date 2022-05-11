defmodule Philomena.TagChangeRevertWorker do
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges
  alias Philomena.Batch
  import Ecto.Query

  def perform(%{"user_id" => user_id, "attributes" => attributes}) do
    TagChange
    |> where(user_id: ^user_id)
    |> revert_all(attributes)
  end

  def perform(%{"ip" => ip, "attributes" => attributes}) do
    TagChange
    |> where(ip: ^ip)
    |> revert_all(attributes)
  end

  def perform(%{"fingerprint" => fp, "attributes" => attributes}) do
    TagChange
    |> where(fingerprint: ^fp)
    |> revert_all(attributes)
  end

  defp revert_all(queryable, attributes) do
    Batch.query_batches(queryable, [batch_size: 100], fn ids ->
      TagChanges.mass_revert(ids, attributes)
    end)
  end
end
