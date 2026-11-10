defmodule Philomena.Topics.MoveForm do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :target_forum, :string
  end

  @doc false
  def changeset(move_form, attrs \\ %{}) do
    move_form
    |> cast(attrs, [:target_forum])
    |> validate_required(:target_forum)
  end

  @doc false
  def fetch_target_forum_short_name(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:create)
    |> case do
      {:ok, move_form} ->
        {:ok, move_form.target_forum}

      _ ->
        {:error, :not_found}
    end
  end
end
