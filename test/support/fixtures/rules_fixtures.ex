defmodule Philomena.RulesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Rules` context.
  """

  alias Philomena.Rules
  alias Philomena.AttributionFixtures
  alias Philomena.UsersFixtures

  @doc """
  Creates a rule with an initial version.

  Positions are unique because rules derive `Phoenix.Param` from
  `:position`, so duplicate positions would make routes ambiguous.
  """
  def rule_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        name: "Test Rule ##{unique}",
        position: unique
      })

    actor = AttributionFixtures.actor(UsersFixtures.admin_user_fixture())
    {:ok, [rule, _version]} = Rules.create_rule(actor, attrs)

    rule
  end
end
