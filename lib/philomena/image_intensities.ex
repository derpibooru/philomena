defmodule Philomena.ImageIntensities do
  @moduledoc """
  Persistence for image intensity data derived by the media pipeline.

  Intensities are owned by an already-loaded image and are not caller-managed
  or request-authorized records.
  """

  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.Images.Image
  alias Philomena.Repo
  alias PhilomenaMedia.Intensities

  @doc """
  Stores the derived intensities for a loaded image.

  There is exactly one row per image, enforced by the database, and the
  row is deleted by the image foreign key when its image is deleted.

  ## Examples

      iex> put_for_loaded_image(image, %Intensities{nw: 0.1, ne: 0.2, sw: 0.3, se: 0.4})
      {:ok, %ImageIntensity{image_id: 42}}

  """
  @spec put_for_loaded_image(Image.t(), Intensities.t()) ::
          {:ok, ImageIntensity.t()} | {:error, Ecto.Changeset.t()}
  def put_for_loaded_image(%Image{} = image, %Intensities{} = intensities) do
    %ImageIntensity{image_id: image.id}
    |> ImageIntensity.changeset(Map.from_struct(intensities))
    |> Repo.insert(
      conflict_target: [:image_id],
      on_conflict: {:replace, [:nw, :ne, :sw, :se]},
      returning: true
    )
  end
end
