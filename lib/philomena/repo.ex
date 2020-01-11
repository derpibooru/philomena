defmodule Philomena.Repo do
  alias Ecto.Multi

  use Ecto.Repo,
    otp_app: :philomena,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 250

  @levels %{
    read_committed: "READ COMMITTED",
    repeatable_read: "REPEATABLE READ",
    serializable: "SERIALIZABLE"
  }

  def isolated_transaction(%Multi{} = multi, level) do
    Multi.append(
      Multi.new()
      |> Multi.run(:isolate, fn repo, _chg ->
        repo.query!("SET TRANSACTION ISOLATION LEVEL #{@levels[level]}")
        {:ok, nil}
      end),
      multi
    )
    |> Philomena.Repo.transaction()
  end
end
