defmodule PhilomenaWeb.UserAttributionView do
  alias Philomena.Attribution
  use Bitwise
  use PhilomenaWeb, :view

  def anonymous_name(object) do
    salt = anonymous_name_salt()
    id = Attribution.object_identifier(object)
    user_id = Attribution.best_user_identifier(object)

    (:erlang.crc32(salt <> id <> user_id) &&& 0xffff)
    |> Integer.to_string(16)
  end

  defp anonymous_name_salt do
    Application.get_env(:philomena, :anonymous_name_salt)
    |> to_string()
  end
end
