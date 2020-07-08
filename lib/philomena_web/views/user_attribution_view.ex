defmodule PhilomenaWeb.UserAttributionView do
  use PhilomenaWeb, :view
  use Bitwise

  alias Philomena.Attribution
  alias PhilomenaWeb.AvatarGeneratorView

  def anonymous?(object) do
    Attribution.anonymous?(object)
  end

  def name(object) do
    case is_nil(object.user) or anonymous?(object) do
      true -> anonymous_name(object)
      _false -> object.user.name
    end
  end

  def avatar_url(object) do
    case is_nil(object.user) or anonymous?(object) do
      true -> anonymous_avatar_url(anonymous_name(object))
      _false -> user_avatar_url(object)
    end
  end

  def anonymous_name(object, reveal_anon? \\ false) do
    salt = anonymous_name_salt()
    id = Attribution.object_identifier(object)
    user_id = Attribution.best_user_identifier(object)

    {:ok, <<key::size(16)>>} = :pbkdf2.pbkdf2(:sha256, id <> user_id, salt, 100, 2)

    hash =
      key
      |> Integer.to_string(16)
      |> String.pad_leading(4, "0")

    case not is_nil(object.user) and reveal_anon? do
      true -> "#{object.user.name} (##{hash}, hidden)"
      false -> "Anonymous ##{hash}"
    end
  end

  def anonymous_avatar(name, class \\ "avatar--100px") do
    class = Enum.join(["image-constrained", class], " ")

    content_tag :div, class: class do
      AvatarGeneratorView.generated_avatar(name)
    end
  end

  def user_avatar(object, class \\ "avatar--100px")

  def user_avatar(%{user: nil} = object, class),
    do: anonymous_avatar(anonymous_name(object), class)

  def user_avatar(%{user: %{avatar: nil}} = object, class),
    do: anonymous_avatar(object.user.name, class)

  def user_avatar(%{user: %{avatar: avatar}}, class) do
    class = Enum.join(["image-constrained", class], " ")

    content_tag :div, class: class do
      img_tag(avatar_url_root() <> "/" <> avatar)
    end
  end

  def user_avatar_url(%{user: %{avatar: nil}} = object) do
    anonymous_avatar_url(object.user.name)
  end

  def user_avatar_url(%{user: %{avatar: avatar}}) do
    avatar_url_root() <> "/" <> avatar
  end

  def anonymous_avatar_url(name) do
    svg =
      name
      |> AvatarGeneratorView.generated_avatar()
      |> Enum.map_join(&safe_to_string/1)

    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

  def user_labels(%{user: user}) do
    []
    |> personal_title(user)
    |> secondary_role(user)
    |> staff_role(user)
  end

  defp personal_title(labels, %{personal_title: t}) do
    case blank?(t) do
      true -> labels
      false -> [{"label--primary", t} | labels]
    end
  end

  defp personal_title(labels, _user), do: labels

  defp secondary_role(labels, %{secondary_role: t}) do
    case blank?(t) do
      true -> labels
      false -> [{"label--warning", t} | labels]
    end
  end

  defp secondary_role(labels, _user), do: labels

  defp staff_role(labels, %{hide_default_role: false, role: "admin"}),
    do: [{"label--danger", "Site Administrator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "moderator"}),
    do: [{"label--success", "Site Moderator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "assistant"}),
    do: [{"label--purple", "Site Assistant"} | labels]

  defp staff_role(labels, _user),
    do: labels

  defp avatar_url_root do
    Application.get_env(:philomena, :avatar_url_root)
  end

  defp anonymous_name_salt do
    Application.get_env(:philomena, :anonymous_name_salt)
    |> to_string()
  end
end
