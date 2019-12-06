defimpl Philomena.Attribution, for: Philomena.Versions.Version do
  def object_identifier(version) do
    to_string(version.parent.id)
  end

  def best_user_identifier(version) do
    to_string(version.user.id)
  end

  def anonymous?(version) do
    same_user?(version.user, version.parent) and !!version.parent.anonymous
  end

  defp same_user?(%{id: id}, %{user_id: id}), do: true
  defp same_user?(_user, _parent), do: false
end