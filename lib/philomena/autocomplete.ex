defmodule Philomena.Autocomplete do
  @moduledoc """
  Public access to the pregenerated autocomplete binary stored in PostgreSQL.

  Browsers download the opaque binary and search it locally, avoiding a server
  round trip for each suggestion. Reading is deliberately unauthenticated.
  Generation is an operational service used by the release task.
  """

  import Ecto.Query, warn: false

  alias Philomena.Autocomplete.{Autocomplete, Generator}
  alias Philomena.Loader
  alias Philomena.Repo

  defp latest_query do
    Autocomplete
    |> order_by(desc: :created_at)
    |> limit(1)
  end

  defp replace_autocomplete!(content) do
    Repo.transact(fn ->
      Repo.delete_all(Autocomplete)

      autocomplete =
        %Autocomplete{}
        |> Autocomplete.changeset(%{content: content})
        |> Repo.insert!()

      {:ok, autocomplete}
    end)
  end

  @doc """
  Loads the current compiled autocomplete artifact.

  Before the first successful generation, it returns `{:error, :not_found}`.

  ## Examples

      iex> show_compiled_autocomplete()
      {:error, :not_found}

      iex> show_compiled_autocomplete()
      {:ok, %Autocomplete{}}

  """
  @spec show_compiled_autocomplete() :: {:ok, Autocomplete.t()} | {:error, :not_found}
  def show_compiled_autocomplete do
    latest_query()
    |> Loader.one()
  end

  @doc """
  Generates and atomically replaces the compiled autocomplete artifact.

  Binary generation runs before the replacement transaction. The transaction
  deletes every previous row and inserts exactly one new row, so readers see
  either the old artifact or the complete replacement. Raises when generation
  or persistence violates an invariant.

  ## Examples

      iex> generate_autocomplete!()
      %Autocomplete{}

  """
  @spec generate_autocomplete!() :: Autocomplete.t()
  def generate_autocomplete! do
    content = Generator.generate()
    {:ok, autocomplete} = replace_autocomplete!(content)
    autocomplete
  end
end
