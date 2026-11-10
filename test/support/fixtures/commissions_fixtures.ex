defmodule Philomena.CommissionsFixtures do
  @moduledoc """
  Test-only commission builders. They persist schemas directly because the
  production context intentionally exposes only actor-scoped APIs, whose
  verified-link policy is unrelated to most fixtures using commission data.
  """

  import Ecto.Query

  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Item
  alias Philomena.Repo

  @doc """
  Creates an open commission sheet for `user`.
  """
  def commission_fixture(user, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        information: "Test commission information",
        contact: "Test contact info",
        will_create: "Test subjects",
        open: true
      })

    user
    |> Ecto.build_assoc(:commission)
    |> Commission.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Adds an item to `commission` (and bumps its `commission_items_count`,
  which the directory listing filters on).
  """
  def commission_item_fixture(commission, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        item_type: "Sketch",
        description: "Test item description",
        base_price: 20
      })

    Repo.transaction(fn ->
      item =
        commission
        |> Ecto.build_assoc(:items)
        |> Item.changeset(attrs)
        |> Repo.insert!()

      {1, _rows} =
        Repo.update_all(
          where(Commission, id: ^commission.id),
          inc: [commission_items_count: 1]
        )

      item
    end)
    |> case do
      {:ok, item} -> item
    end
  end
end
