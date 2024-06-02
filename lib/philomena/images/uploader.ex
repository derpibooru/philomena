defmodule Philomena.Images.Uploader do
  @moduledoc """
  Upload and processing callback logic for Images.
  """

  alias Philomena.Images.Thumbnailer
  alias Philomena.Images.Image
  alias PhilomenaMedia.Uploader

  def analyze_upload(image, params) do
    Uploader.analyze_upload(image, "image", params["image"], &Image.image_changeset/2)
  end

  def persist_upload(image) do
    Thumbnailer.upload_file(image, image.uploaded_image, "full.#{image.image_format}")
  end
end
