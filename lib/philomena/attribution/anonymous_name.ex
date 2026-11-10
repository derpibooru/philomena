defmodule Philomena.Attribution.AnonymousName do
  @moduledoc """
  Generates the stable pseudonym used for anonymous attribution.

  The hash is scoped by the attributed object's parent identifier and the best
  available user, fingerprint, or IP identifier.
  """

  alias Philomena.Attribution

  @spec anonymous?(struct()) :: boolean()
  def anonymous?(object) do
    not is_nil(Attribution.impl_for(object)) and Attribution.anonymous?(object)
  end

  @spec anonymous_user?(struct()) :: boolean()
  def anonymous_user?(object), do: is_nil(object.user) or anonymous?(object)

  @spec name(struct()) :: String.t()
  def name(object) do
    if anonymous_user?(object), do: generate(object), else: object.user.name
  end

  @spec generate(struct(), boolean()) :: String.t()
  def generate(object, reveal_anonymous? \\ false) do
    salt = Application.get_env(:philomena, :anonymous_name_salt) |> to_string()
    object_id = Attribution.object_identifier(object)
    user_id = Attribution.best_user_identifier(object)

    {:ok, <<key::size(16)>>} =
      :pbkdf2.pbkdf2(:sha256, object_id <> user_id, salt, 100, 2)

    hash = key |> Integer.to_string(16) |> String.pad_leading(4, "0")

    if object.user && reveal_anonymous? do
      "#{object.user.name} (##{hash}, hidden)"
    else
      "Background Pony ##{hash}"
    end
  end
end
