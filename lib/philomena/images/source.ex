defmodule Philomena.Images.Source do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image

  schema "image_sources" do
    belongs_to :image, Image
    field :source, :string
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:source])
    |> validate_required([:source])
    |> validate_format(:source, ~r/\Ahttps?:\/\//)
    |> ignore_if_blank()
  end

  defp ignore_if_blank(%{valid?: false, changes: changes} = changeset) when changes == %{},
    do: %{changeset | action: :ignore}

  defp ignore_if_blank(changeset),
    do: changeset
end
