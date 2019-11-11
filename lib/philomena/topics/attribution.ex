defimpl Philomena.Attribution, for: Philomena.Topics.Topic do
  def object_identifier(topic) do
    to_string(topic.id)
  end

  def best_user_identifier(topic) do
    to_string(topic.user_id)
  end
end