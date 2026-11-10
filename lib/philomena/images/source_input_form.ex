defmodule Philomena.Images.SourceInputForm do
  use Ecto.Schema

  import Ecto.Changeset

  alias Philomena.Images.Source

  @type t :: %__MODULE__{}

  embedded_schema do
    embeds_many :old_sources, Source
    embeds_many :sources, Source
  end

  @doc false
  def changeset(%__MODULE__{} = form, attrs \\ %{}) do
    form
    |> cast(attrs, [])
    |> cast_embed(:old_sources, with: &Source.input_changeset/2)
    |> cast_embed(:sources, with: &Source.input_changeset/2)
  end

  @doc false
  def apply(form_changeset, image) do
    if form_changeset.valid? do
      {:ok, apply_changes(form_changeset)}
    else
      image_changeset =
        image
        |> change()
        |> attach_old_sources_errors(form_changeset)
        |> attach_sources_errors(form_changeset)
        |> attach_errors(form_changeset)

      {:error, image_changeset}
    end
  end

  defp attach_old_sources_errors(
         image_changeset,
         %{changes: %{old_sources: old_sources_changes}}
       ) do
    if Enum.all?(old_sources_changes, & &1.valid?) do
      image_changeset
    else
      add_error(image_changeset, :old_sources, "is invalid")
    end
  end

  defp attach_old_sources_errors(image_changeset, _changes),
    do: image_changeset

  defp attach_sources_errors(
         image_changeset,
         %{changes: %{sources: sources_changes}}
       ) do
    put_assoc(image_changeset, :sources, sources_changes)
  end

  defp attach_sources_errors(image_changeset, _changes),
    do: image_changeset

  defp attach_errors(image_changeset, %{errors: errors}) do
    Enum.reduce(errors, image_changeset, fn {field, {message, opts}}, image_changeset ->
      add_error(image_changeset, field, message, opts)
    end)
  end
end
