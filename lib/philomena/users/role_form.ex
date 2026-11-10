defmodule Philomena.Users.RoleForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :roles, {:array, :integer}, default: []
  end

  @doc false
  def fetch_role_ids(attrs) do
    # Each checkbox group in the admin form submits a blank sentinel value.
    attrs = Map.replace_lazy(attrs, "roles", &Enum.reject(List.wrap(&1), fn id -> id == "" end))

    %__MODULE__{}
    |> cast(attrs, [:roles])
    |> update_change(:roles, &Enum.uniq/1)
    |> apply_action(:create)
    |> case do
      {:ok, %{roles: role_ids}} ->
        {:ok, role_ids}

      _error ->
        {:error, :not_found}
    end
  end
end
