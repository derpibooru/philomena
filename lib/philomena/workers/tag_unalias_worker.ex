defmodule Philomena.TagUnaliasWorker do
  alias Philomena.Tags

  def perform(tag_id) do
    Tags.perform_unalias(tag_id)
  end
end
