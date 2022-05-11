defmodule Philomena.TagChangeRevertWorker do
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges
  alias Philomena.Batch
  alias Philomena.Repo
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
    Batch.query_batches(queryable, [batch_size: 100], fn queryable ->
      ids = Repo.all(select(queryable, [tc], tc.id))
      TagChanges.mass_revert(ids, cast_ip(atomify_keys(attributes)))
    end)
  end

  defp atomify_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp cast_ip(attributes) do
    %{attributes | ip: elem(EctoNetwork.INET.cast(attributes[:ip]), 1)}
  end
end
