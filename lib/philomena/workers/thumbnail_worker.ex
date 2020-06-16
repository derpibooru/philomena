defmodule Philomena.ThumbnailWorker do
  alias Philomena.Images.Thumbnailer

  def perform(image_id) do
    Thumbnailer.generate_thumbnails(image_id)

    PhilomenaWeb.Endpoint.broadcast!(
      "firehose",
      "image:process",
      %{image_id: image_id}
    )
  end
end
