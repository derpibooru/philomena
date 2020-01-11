defimpl Philomena.Attribution, for: Philomena.SourceChanges.SourceChange do
  def object_identifier(source_change) do
    to_string(source_change.image_id || source_change.id)
  end

  def best_user_identifier(source_change) do
    to_string(source_change.user_id || source_change.fingerprint || source_change.ip)
  end

  def anonymous?(source_change) do
    source_change.user_id == source_change.image.user_id and !!source_change.image.anonymous
  end
end
