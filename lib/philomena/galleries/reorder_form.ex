defmodule Philomena.Galleries.ReorderForm do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @max_image_ids 250

  alias Philomena.Galleries.Gallery

  embedded_schema do
    belongs_to :gallery, Gallery

    field :image_ids, {:array, :integer}
  end

  @doc false
  def changeset(%__MODULE__{} = reorder_form, attrs \\ %{}) do
    reorder_form
    |> cast(attrs, [:image_ids])
    |> validate_required(:image_ids)
    |> validate_length(:image_ids, min: 1, max: @max_image_ids)
    |> validate_change(:image_ids, fn :image_ids, image_ids ->
      if Enum.uniq(image_ids) == image_ids do
        []
      else
        [image_ids: "must contain unique image IDs"]
      end
    end)
  end

  @doc false
  def membership_changeset(%__MODULE__{} = reorder_form, %Gallery{} = gallery, valid_image_ids) do
    changeset =
      reorder_form
      |> Map.put(:gallery, gallery)
      |> change()

    if Enum.sort(valid_image_ids) == Enum.sort(reorder_form.image_ids) do
      changeset
    else
      add_error(changeset, :image_ids, "must belong to the gallery")
    end
  end
end
