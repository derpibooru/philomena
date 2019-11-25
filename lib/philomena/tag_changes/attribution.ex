defimpl Philomena.Attribution, for: Philomena.TagChanges.TagChange do
  def object_identifier(tag_change) do
    to_string(tag_change.image_id || tag_change.id)
  end

  def best_user_identifier(tag_change) do
    to_string(tag_change.user_id || tag_change.fingerprint || tag_change.ip)
  end

  def anonymous?(tag_change) do
    tag_change.user_id == tag_change.image.user_id and !!tag_change.image.anonymous
  end
end