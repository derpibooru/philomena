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

  def init(_type, config) do
    config = Keyword.put(config, :username, System.get_env("POSTGRES_USER"))
    config = Keyword.put(config, :password, System.get_env("POSTGRES_PASSWORD"))
    config = Keyword.put(config, :hostname, System.get_env("POSTGRES_HOST"))
    config = Keyword.put(config, :database, System.get_env("POSTGRES_DB"))
    config = Keyword.put(config, :port, System.get_env("POSTGRES_PORT"))
    #config = Keyword.put(config, :database, Application.get_env(:philomena, Philomena, :database))
    #config = Keyword.put(config, :hostname, Application.get_env(:philomena, Philomena, :hostname))
    #config = Keyword.put(config, :port, Application.get_env(:philomena, Philomena, :port))
    #config = Keyword.put(config, :username, Application.get_env(:philomena, Philomena, :username))
    #config = Keyword.put(config, :password, Application.get_env(:philomena, Philomena, :password))
    {:ok, config }
  end

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
