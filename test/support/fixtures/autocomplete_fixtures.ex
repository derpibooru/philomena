defmodule Philomena.AutocompleteFixtures do
  @moduledoc """
  Test helpers for the `Philomena.Autocomplete` context (the pregenerated
  local autocomplete binary served by `Autocomplete.CompiledController`).
  """

  alias Philomena.Autocomplete.Autocomplete
  alias Philomena.Repo

  @doc """
  Inserts an autocomplete row with the given binary `content`.

  `Autocomplete.generate_autocomplete!/0` builds a real binary from the tag
  table; controller tests only need a row present whose bytes they can compare
  against, so this inserts one directly the way the changeset would.
  """
  def autocomplete_fixture(content \\ <<0, 1, 2, 3>>) do
    %Autocomplete{}
    |> Autocomplete.changeset(%{content: content})
    |> Repo.insert!()
  end
end
