defmodule Philomena.Repo do
  use Ecto.Repo,
    otp_app: :philomena,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 250

  @levels %{
    read_committed: "READ COMMITTED",
    repeatable_read: "REPEATABLE READ",
    serializable: "SERIALIZABLE"
  }

  def isolated_transaction(f, level) do
    Philomena.Repo.transaction(fn ->
      Philomena.Repo.query!("SET TRANSACTION ISOLATION LEVEL #{@levels[level]}")
      Philomena.Repo.transaction(f)
    end)
    |> case do
      {:ok, value} ->
        value

      error ->
        error
    end
  end
end
