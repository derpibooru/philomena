defmodule Philomena.CommentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Comments` context.
  """

  import Philomena.AttributionFixtures

  alias Philomena.Comments

  @doc """
  Creates a comment on `image`, authored by `user` (anonymous attribution
  when `nil`).
  """
  def comment_fixture(image, user \\ nil, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{"body" => "Test comment body"})

    {:ok, comment} = Comments.create_comment(actor(user, ip: random_ip()), image.id, attrs)

    comment
  end
end
