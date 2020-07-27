defmodule Philomena.Notable do

  import Ecto.Query, warn: false

  alias Philomena.Repo
  alias Philomena.Notable.Name

  @doc """
  List all notable names.
  """
  def list_names do
    Repo.all(Name)
  end

  @doc """
  Checks username against table of notable names.
  """
  def notable_name?(name) do
    if have_table() do
      name = name |> String.downcase
		  Repo.exists?(from n in Name,
        where: fragment("lower(?)", n.name) == ^name)
    else
      false
    end
  end

  defp have_table() do
    alias Ecto.Adapters.SQL

    SQL.table_exists?(Repo, "notable_names")
  end
end
