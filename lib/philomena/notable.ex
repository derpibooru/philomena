defmodule Philomena.Notable do

  import Ecto.Query, warn: false
  alias Ecto.Adapters.SQL

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
      case nnquery(name) do
        {:ok, res} ->
          res.num_rows > 0
        {:error, err} ->
          false
      end
    else
      false
    end
  end

  defp nnquery(name) do
    SQL.query(Repo, "SELECT * FROM notable_name_query($1)", [name])
  end

  defp have_table() do
    SQL.table_exists?(Repo, "notable_names")
  end
end
