defmodule Philomena.TagDeleteWorker do
  alias Philomena.Tags

  def perform(tag_id) do
    Tags.perform_delete(tag_id)
  end
end
