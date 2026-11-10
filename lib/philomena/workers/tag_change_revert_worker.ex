defmodule Philomena.TagChangeRevertWorker do
  @moduledoc """
  Reverts every tag change made by a user, IP, or fingerprint, batching by
  image so each image's tag history is reverted in a single operation.
  """

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
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
    attributes = cast_ip(atomify_keys(attributes))

    case TagChanges.revert_all_for_worker(queryable, attributes) do
      :ok -> :ok
      {:error, reason} -> raise "tag change batch revert failed: #{inspect(reason)}"
    end
  end

  defp atomify_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp cast_ip(attributes) do
    %{attributes | ip: elem(EctoNetwork.INET.cast(attributes[:ip]), 1)}
  end
end
