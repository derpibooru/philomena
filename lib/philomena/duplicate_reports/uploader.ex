defmodule Philomena.DuplicateReports.Uploader do
  @moduledoc """
  Upload and processing callback logic for SearchQuery images.
  """

  alias Philomena.DuplicateReports.SearchQuery
  alias PhilomenaMedia.Uploader

  def analyze_upload(search_query, params) do
    Uploader.analyze_upload(
      search_query,
      "image",
      params["image"],
      &SearchQuery.image_changeset/2
    )
  end
end
