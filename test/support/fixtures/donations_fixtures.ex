defmodule Philomena.DonationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Donations` context.
  """

  alias Philomena.Donations
  alias Philomena.AttributionFixtures
  alias Philomena.UsersFixtures

  @doc """
  Creates a donation, optionally attributed to `user` (the schema allows a
  `nil` user). String-keyed attrs mirror the admin donation form
  (`"email"`, `"amount"`, `"note"`, `"user_id"`); every field is optional in
  the changeset, so a bare call still inserts a row.
  """
  def donation_fixture(user \\ nil, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        "email" => "donor#{System.unique_integer([:positive])}@example.com",
        "amount" => "5.00",
        "note" => "Test donation"
      })
      |> maybe_put_user(user)

    actor = AttributionFixtures.actor(UsersFixtures.admin_user_fixture())
    {:ok, donation} = Donations.create_donation(actor, attrs)
    donation
  end

  defp maybe_put_user(attrs, nil), do: attrs
  defp maybe_put_user(attrs, user), do: Map.put_new(attrs, "user_id", user.id)
end
