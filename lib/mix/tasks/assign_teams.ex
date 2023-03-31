defmodule Mix.Tasks.AssignTeams do
  use Mix.Task

  alias Philomena.Users.User
  alias Philomena.Games
  alias Philomena.Repo
  alias Philomena.Batch

  @shortdoc "Assigns an initial team to all users."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(_args) do
    User
    |> Batch.query_batches(fn q ->
      q
      |> Repo.all()
      |> Enum.each(fn u ->
        Games.create_player(u)
      end)
    end)
  end
end
