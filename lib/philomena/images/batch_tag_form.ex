defmodule Philomena.Images.BatchTagForm do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :tag_list, :string
    field :image_ids, {:array, :integer}
  end

  @doc false
  def changeset(%__MODULE__{} = form, attrs \\ %{}) do
    form
    |> cast(attrs, [:image_ids, :tag_list])
    |> validate_required([:image_ids, :tag_list])
    |> update_change(:image_ids, &Enum.uniq/1)
  end
end
