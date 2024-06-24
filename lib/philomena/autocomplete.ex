defmodule Philomena.Autocomplete do
  @moduledoc """
  Pregenerated autocomplete files.

  These are used to eliminate the latency of looking up search results on the server.
  A script can parse the binary and generate results directly as the user types, without
  incurring any roundtrip penalty.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Autocomplete.Autocomplete
  alias Philomena.Autocomplete.Generator

  @doc """
  Gets the current local autocompletion binary.

  Returns nil if the binary is not currently generated.

  ## Examples

      iex> get_artist_link()
      nil

      iex> get_autocomplete()
      %Autocomplete{}

  """
  def get_autocomplete do
    Autocomplete
    |> order_by(desc: :created_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Creates a new local autocompletion binary, replacing any which currently exist.
  """
  def generate_autocomplete! do
    ac_file = Generator.generate()

    # Insert the autocomplete binary
    new_ac =
      %Autocomplete{}
      |> Autocomplete.changeset(%{content: ac_file})
      |> Repo.insert!()

    # Remove anything older
    Autocomplete
    |> where([ac], ac.created_at < ^new_ac.created_at)
    |> Repo.delete_all()
  end
end
