defmodule Philomena.Images.Source do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image

  @primary_key false
  schema "image_sources" do
    belongs_to :image, Image, primary_key: true
    field :source, :string, primary_key: true
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:source])
    |> validate_required([:source])
    |> validate_format(:source, ~r/\Ahttps?:\/\//)
    |> validate_length(:source, max: 255)
  end

  @doc false
  def input_changeset(source, attrs) do
    source
    |> changeset(attrs)
    |> ignore_if_blank()
  end

  defp ignore_if_blank(%{valid?: false, changes: changes} = changeset) when changes == %{},
    do: %{changeset | action: :ignore}

  defp ignore_if_blank(changeset),
    do: changeset
end
