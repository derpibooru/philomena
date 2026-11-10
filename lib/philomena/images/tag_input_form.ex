defmodule Philomena.Images.TagInputForm do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :old_tag_input, :string
    field :tag_input, :string
  end

  @type t :: %__MODULE__{}

  @doc false
  def changeset(%__MODULE__{} = form, attrs \\ %{}) do
    cast(form, attrs, [:old_tag_input, :tag_input])
  end

  @doc false
  def apply(form_changeset, image) do
    if form_changeset.valid? do
      {:ok, apply_changes(form_changeset)}
    else
      image_changeset =
        Enum.reduce(
          form_changeset.errors,
          change(image),
          fn {field, {message, opts}}, image_changeset ->
            add_error(image_changeset, field, message, opts)
          end
        )

      {:error, image_changeset}
    end
  end
end
