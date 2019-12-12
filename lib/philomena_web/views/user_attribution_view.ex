defmodule PhilomenaWeb.UserAttributionView do
  alias Philomena.Attribution
  use Bitwise
  use PhilomenaWeb, :view

  def anonymous?(object) do
    Attribution.anonymous?(object)
  end

  def anonymous_name(object, reveal_anon? \\ false) do
    salt = anonymous_name_salt()
    id = Attribution.object_identifier(object)
    user_id = Attribution.best_user_identifier(object)

    hash =
      (:erlang.crc32(salt <> id <> user_id) &&& 0xffff)
      |> Integer.to_string(16)
      |> String.pad_leading(4, "0")

    case reveal_anon? do
      true  -> "#{object.user.name} (##{hash}, hidden)"
      false -> "Background Pony ##{hash}"
    end
  end

  def anonymous_avatar(_object, class \\ "avatar--100px") do
    class = Enum.join(["image-constrained", class], " ")

    content_tag :div, [class: class] do
      img_tag(Routes.static_path(PhilomenaWeb.Endpoint, "/images/no_avatar.svg"))
    end
  end

  def user_avatar(object, class \\ "avatar--100px")

  def user_avatar(%{user: nil} = object, class),
    do: anonymous_avatar(object, class)
  def user_avatar(%{user: %{avatar: nil}} = object, class),
    do: anonymous_avatar(object, class)
  def user_avatar(%{user: %{avatar: avatar}}, class) do
    class = Enum.join(["image-constrained", class], " ")

    content_tag :div, [class: class] do
      img_tag(avatar_url_root() <> "/" <> avatar)
    end
  end

  def user_labels(%{user: user}) do
    []
    |> personal_title(user)
    |> secondary_role(user)
    |> staff_role(user)
  end

  defp personal_title(labels, %{personal_title: t}) do
    case blank?(t) do
      true  -> labels
      false -> [{"label--primary", t} | labels]
    end
  end
  defp personal_title(labels, _user), do: labels

  defp secondary_role(labels, %{secondary_role: t}) do
    case blank?(t) do
      true  -> labels
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
