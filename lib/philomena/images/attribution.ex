defimpl Philomena.Attribution, for: Philomena.Images.Image do
  def object_identifier(image) do
    to_string(image.id)
  end

  def best_user_identifier(image) do
    to_string(image.user_id || image.fingerprint || image.ip)
  end
end