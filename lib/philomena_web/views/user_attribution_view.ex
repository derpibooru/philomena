defmodule PhilomenaWeb.UserAttributionView do
  use PhilomenaWeb, :view

  alias Philomena.Attribution.AnonymousName
  alias PhilomenaWeb.AvatarGeneratorView
  alias Philomena.Repo

  defdelegate anonymous?(object), to: AnonymousName

  defdelegate anonymous_user?(object), to: AnonymousName

  defdelegate name(object), to: AnonymousName

  def avatar_url(object) do
    if anonymous_user?(object) do
      anonymous_avatar_url(anonymous_name(object))
    else
      user_avatar_url(object)
    end
  end

  def anonymous_name(object, reveal_anon? \\ false),
    do: AnonymousName.generate(object, reveal_anon?)

  def user_avatar(object, opts \\ []) do
    class = Keyword.get(opts, :class) || "avatar--100px"
    no_profile_link = Keyword.get(opts, :no_profile_link) || false

    anon = anonymous_user?(object)

    content =
      if anon or is_nil(object.user.avatar) do
        AvatarGeneratorView.generated_avatar(name(object))
      else
        img_tag(avatar_url_root() <> "/" <> object.user.avatar)
      end

    {tag, attrs} =
      if anon or no_profile_link do
        {:div, []}
      else
        {:a, href: ~p"/profiles/#{object.user}"}
      end

    attrs = Keyword.put(attrs, :class, "image-constrained #{class}")

    content_tag(tag, content, attrs)
  end

  defp user_avatar_url(%{user: %{avatar: nil}} = object) do
    anonymous_avatar_url(object.user.name)
  end

  defp user_avatar_url(%{user: %{avatar: avatar}}) do
    avatar_url_root() <> "/" <> avatar
  end

  defp anonymous_avatar_url(name) do
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

  def team_data_for_user(user) do
    user = Repo.preload(user, :game_profiles)
    game_profile = Repo.preload(user.game_profiles, :team) |> Enum.at(0)

    %{
      name: if(game_profile.team.id == 1, do: "NLR", else: "SE"),
      icon: if(game_profile.team.id == 1, do: "/nlr.svg", else: "/se.svg"),
      points: game_profile.points,
      style:
        if(game_profile.team.id == 1, do: "game__team_banner--nlr", else: "game__team_banner--se")
    }
  end

  def rank_for_user(user) do
    user = Repo.preload(user, :game_profiles)

    rank_string_from_profile(Enum.at(user.game_profiles, 0))
  end

  defp rank_string_from_profile(%{points: points, rank_override: nil}) do
    case points do
      n when n == 6969 -> "V.NICE"
      n when n >= 5000 -> "A"
      n when n >= 2000 -> "B"
      n when n == 1337 -> "L33T"
      n when n == 666 -> "SATAN"
      n when n >= 500 -> "C"
      n when n == 420 -> "GRASS"
      n when n >= 100 -> "D"
      n when n == 69 -> "NICE"
      n when n >= 25 -> "E"
      n when n >= 5 -> "F"
      _ -> "NONE"
    end
  end

  defp rank_string_from_profile(%{rank_override: override}), do: override
  defp rank_string_from_profile(_), do: "NONE"

  defp personal_title(labels, %{personal_title: t}) do
    if blank?(t) do
      labels
    else
      [{"label--primary", t} | labels]
    end
  end

  defp personal_title(labels, _user), do: labels

  defp secondary_role(labels, %{secondary_role: t}) do
    if blank?(t) do
      labels
    else
      [{"label--warning", t} | labels]
    end
  end

  defp secondary_role(labels, _user), do: labels

  defp staff_role(labels, %{hide_default_role: false, role: "admin", senior_staff: true}),
    do: [{"label--danger", "Head Administrator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "admin"}),
    do: [{"label--danger", "Administrator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "moderator", senior_staff: true}),
    do: [{"label--success", "Senior Moderator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "moderator"}),
    do: [{"label--success", "Moderator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "assistant", senior_staff: true}),
    do: [{"label--purple", "Senior Assistant"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "assistant"}),
    do: [{"label--purple", "Assistant"} | labels]

  defp staff_role(labels, _user),
    do: labels

  defp avatar_url_root do
    Application.get_env(:philomena, :avatar_url_root)
  end
end
