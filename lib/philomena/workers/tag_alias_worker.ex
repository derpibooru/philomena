defmodule Philomena.TagAliasWorker do
  alias Philomena.Tags

  def perform(tag_id, target_tag_id) do
    Tags.perform_alias(tag_id, target_tag_id)
  end
end
