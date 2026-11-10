defmodule Philomena.DuplicateReports.Uploader do
  @moduledoc false

  alias Philomena.DuplicateReports.SearchQuery
  alias PhilomenaMedia.Uploader

  @doc false
  def analyze_upload(search_query, upload) do
    Uploader.analyze_upload(
      search_query,
      "image",
      upload,
      &SearchQuery.image_changeset/2
    )
  end
end
