defmodule Philomena.DuplicateReports.SearchQuery do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :distance, :float, default: 0.25
    field :limit, :integer, default: 10

    field :image_width, :integer
    field :image_height, :integer
    field :image_format, :string
    field :image_duration, :float
    field :image_mime_type, :string
    field :image_is_animated, :boolean
    field :image_aspect_ratio, :float
    field :uploaded_image, :string, virtual: true
  end

  @doc false
  def changeset(search_query, attrs \\ %{}) do
    search_query
    |> cast(attrs, [:distance, :limit])
    |> validate_number(:distance, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:limit, greater_than_or_equal_to: 1, less_than_or_equal_to: 50)
  end

  @doc false
  def image_changeset(search_query, attrs \\ %{}) do
    search_query
    |> cast(attrs, [
      :image_width,
      :image_height,
      :image_format,
      :image_duration,
      :image_mime_type,
      :image_is_animated,
      :image_aspect_ratio,
      :uploaded_image
    ])
    |> validate_required([
      :image_width,
      :image_height,
      :image_format,
      :image_duration,
      :image_mime_type,
      :image_is_animated,
      :image_aspect_ratio,
      :uploaded_image
    ])
    |> validate_number(:image_width, greater_than: 0)
    |> validate_number(:image_height, greater_than: 0)
    |> validate_inclusion(
      :image_mime_type,
      ~W(image/gif image/jpeg image/png image/svg+xml video/webm),
      message: "(#{attrs["image_mime_type"]}) is invalid"
    )
  end

  @doc false
  def to_analysis(search_query) do
    %PhilomenaMedia.Analyzers.Result{
      animated?: search_query.image_is_animated,
      dimensions: {search_query.image_width, search_query.image_height},
      duration: search_query.image_duration,
      extension: search_query.image_format,
      mime_type: search_query.image_mime_type
    }
  end
end
