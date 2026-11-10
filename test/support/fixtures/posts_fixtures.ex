defmodule Philomena.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Posts` context.
  """

  import Philomena.AttributionFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Posts

  @doc """
  Creates a reply post in `topic`, authored by `user` (anonymous
  attribution when `nil`).
  """
  def post_fixture(topic, user \\ nil, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{"body" => "Test post body"})
    topic = Repo.preload(topic, :forum)

    {actor_user, attrs} =
      if user do
        {user, attrs}
      else
        {admin_user_fixture(), Map.put(attrs, "anonymous", "true")}
      end

    {:ok, post} =
      Posts.create_post(
        actor(actor_user, ip: random_ip()),
        topic.forum.short_name,
        topic.slug,
        attrs
      )

    post
  end
end
