defimpl Philomena.Attribution, for: Philomena.Posts.Post do
  def object_identifier(post) do
    to_string(post.topic_id || post.id)
  end

  def best_user_identifier(post) do
    to_string(post.user_id || post.fingerprint || post.ip)
  end
end