defimpl Phoenix.Param, for: Float do
  # Another Phoenix sadness:
  #
  # "By default, Phoenix implements this protocol for integers, binaries,
  # atoms, and structs."
  #
  @spec to_param(float()) :: binary()
  def to_param(term) do
    Float.to_string(term)
  end
end
