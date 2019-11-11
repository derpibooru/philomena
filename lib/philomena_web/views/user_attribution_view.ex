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

  def anonymous_avatar(_object, class \\ "avatar--100px") do
    img_tag(Routes.static_path(PhilomenaWeb.Endpoint, "/images/no_avatar.svg"), class: class)
  end

  def user_avatar(object, class \\ "avatar--100px") do
    if object.user.avatar do
      img_tag(avatar_url_root() <> object.user.avatar, class: class)
    else
      anonymous_avatar(object, class)
    end
  end

  defp avatar_url_root do
    Application.get_env(:philomena, :avatar_url_root)
  end

  defp anonymous_name_salt do
    Application.get_env(:philomena, :anonymous_name_salt)
    |> to_string()
  end
end
