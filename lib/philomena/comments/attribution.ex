defimpl Philomena.Attribution, for: Philomena.Comments.Comment do
  def object_identifier(comment) do
    to_string(comment.image_id || comment.id)
  end

  def best_user_identifier(comment) do
    to_string(comment.user_id || comment.fingerprint || comment.ip)
  end

  def anonymous?(comment) do
    !!comment.anonymous
  end
end
