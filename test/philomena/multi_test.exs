defmodule Philomena.MultiTest do
  use Philomena.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Tags.Tag

  defp await_semaphore(parent, ready, proceed) do
    send(parent, ready)

    receive do
      ^proceed -> {:ok, :released}
    end
  end

  test "restarts the transaction after a transient conflict" do
    attempts = start_supervised!({Agent, fn -> 0 end})

    multi =
      Multi.new()
      |> Multi.run(:result, fn _repo, _changes ->
        attempt = Agent.get_and_update(attempts, fn count -> {count, count + 1} end)

        case attempt do
          0 -> {:error, :conflict}
          1 -> {:ok, :retried}
        end
      end)

    assert {:ok, %{result: :retried}} = Multi.transact_with_automatic_retry(multi)
    assert Agent.get(attempts, & &1) == 2
  end

  test "restarts the transaction after a serialization failure" do
    attempts = start_supervised!({Agent, fn -> 0 end})

    Sandbox.unboxed_run(Repo, fn ->
      tag_names =
        for suffix <- ["first", "second"] do
          "multi-serialization-#{suffix}-#{System.unique_integer([:positive])}"
        end

      {:ok, %{rows: [[first_tag_id], [second_tag_id]]}} =
        Repo.query(
          """
          INSERT INTO tags (name, slug, created_at, updated_at)
          VALUES ($1, $1, NOW(), NOW()), ($2, $2, NOW(), NOW())
          RETURNING id
          """,
          tag_names
        )

      tag_ids = [first_tag_id, second_tag_id]

      try do
        parent = self()
        read_query = from(tag in Tag, where: tag.id in ^tag_ids, select: tag.id)
        first_update_query = from(tag in Tag, where: tag.id == ^first_tag_id)
        second_update_query = from(tag in Tag, where: tag.id == ^second_tag_id)

        competing_transaction =
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              Multi.new()
              |> Multi.run(:start_semaphore, fn _repo, _changes ->
                await_semaphore(parent, :competing_transaction_ready, :start)
              end)
              |> Multi.all(:read_tags, read_query)
              |> Multi.run(:read_semaphore, fn _repo, _changes ->
                await_semaphore(parent, :competing_transaction_read, :update)
              end)
              |> Multi.update_all(:update_tag, first_update_query, inc: [images_count: 1])
              |> Multi.transact(isolation: :serializable)
            end)
          end)

        assert_receive :competing_transaction_ready

        multi =
          Multi.new()
          |> Multi.run(:start_semaphore, fn _repo, _changes ->
            attempt = Agent.get_and_update(attempts, fn count -> {count, count + 1} end)

            if attempt == 0 do
              await_semaphore(parent, :multi_ready, :start)
            else
              {:ok, :retry}
            end
          end)
          |> Multi.all(:read_tags, read_query)
          |> Multi.run(:read_semaphore, fn _repo, %{start_semaphore: attempt} ->
            if attempt == :retry do
              {:ok, :retry}
            else
              await_semaphore(parent, :multi_read, :update)
            end
          end)
          |> Multi.update_all(:update_tag, second_update_query, inc: [images_count: 1])

        transaction =
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              Multi.transact_with_automatic_retry(multi, isolation: :serializable)
            end)
          end)

        assert_receive :multi_ready
        send(competing_transaction.pid, :start)
        send(transaction.pid, :start)

        assert_receive :competing_transaction_read
        assert_receive :multi_read

        send(competing_transaction.pid, :update)
        assert {:ok, _} = Task.await(competing_transaction)

        send(transaction.pid, :update)
        assert {:ok, %{update_tag: {1, nil}}} = Task.await(transaction)
        assert Agent.get(attempts, & &1) == 2
      after
        Repo.query!("DELETE FROM tags WHERE id IN ($1, $2)", tag_ids)
      end
    end)
  end
end
