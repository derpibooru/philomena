defmodule PhilomenaWeb.UserJson do

  alias PhilomenaWeb.LinksJson
  alias PhilomenaWeb.AwardsJson

  def as_json(conn, user) do
    %{
      id: user.id,
      name: user.name,
      slug: user.slug,
      role: role(user),
      description: user.description,
      avatar_url: avatar_url_root() <> "/" <> user.avatar,
      created_at: user.created_at,
      comments_count: user.comments_posted_count,
      uploads_count: user.uploads_count,
      posts_count: user.forum_posts_count,
      topics_count: user.topic_count,
      links: Enum.map(user.public_links, &LinksJson.as_json(conn, &1)),
      awards: Enum.map(user.awards, &AwardsJson.as_json(conn, &1))
    }
  end

  defp role(%{hide_default_role: true}) do
    "user"
  end

  defp role(user) do
    user.role
  end

  defp avatar_url_root do
    Application.get_env(:philomena, :avatar_url_root)
  end  
end
