defprotocol Philomena.Attribution do
  @doc """
    Provides the "parent object" identifier for this object. This is so
    that anonymous posts under the same topic id can return the same hash
    for the same user.
  """
  @spec object_identifier(struct()) :: String.t()
  def object_identifier(object)

  @doc """
    Provides the "best" user identifier for an object. Usually this will be
    the user_id, but may also be the fingerprint or IP address if other
    information is unavailable.
  """
  @spec best_user_identifier(struct()) :: String.t()
  def best_user_identifier(object)

  @doc """
    Return whether this object is considered to be anonymous.
  """
  @spec anonymous?(struct()) :: true | false
  def anonymous?(object)
end