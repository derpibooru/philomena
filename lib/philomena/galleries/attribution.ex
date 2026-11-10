defimpl Philomena.Attribution, for: Philomena.Galleries.Gallery do
  def object_identifier(gallery) do
    to_string(gallery.id)
  end

  def best_user_identifier(gallery) do
    to_string(gallery.user_id)
  end

  def anonymous?(gallery) do
    gallery.anonymous
  end
end
