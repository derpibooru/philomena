defmodule Philomena.FiltersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Filters` context.
  """

  alias Philomena.Filters
  alias Philomena.Filters.Filter
  alias Philomena.Repo

  def unique_filter_name, do: "Test Filter #{System.unique_integer([:positive])}"

  @doc """
  Creates a filter owned by `user`. Pass `public: true` for a public filter.
  """
  def filter_fixture(user, attrs \\ %{}) do
    {:ok, filter} =
      Filters.create_filter(
        Philomena.AttributionFixtures.actor(user),
        Enum.into(attrs, %{name: unique_filter_name()})
      )

    filter
  end

  @doc """
  Creates a system filter.

  No context function creates system filters (production rows come from the
  seeds), so this mirrors the default-filter insert in
  `PhilomenaWeb.ConnCase`.
  """
  def system_filter_fixture(attrs \\ %{}) do
    %Filter{system: true}
    |> struct!(Enum.into(attrs, %{name: unique_filter_name()}))
    |> Filter.changeset(nil)
    |> Repo.insert!()
  end
end
