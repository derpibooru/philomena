defmodule Philomena.TagReindexWorker do
  alias Philomena.Tags

  def perform(tag_id) do
    Tags.perform_reindex_images(tag_id)
  end
end
