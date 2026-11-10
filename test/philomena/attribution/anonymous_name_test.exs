defmodule Philomena.Attribution.AnonymousNameTest do
  use Philomena.DataCase, async: true

  alias Philomena.Attribution.AnonymousName
  alias Philomena.Posts.Post

  import Philomena.UsersFixtures

  test "generates a stable parent-scoped anonymous pseudonym" do
    post = %Post{
      topic_id: 12,
      fingerprint: "stable-fingerprint",
      anonymous: true,
      user: nil
    }

    assert name = AnonymousName.generate(post)
    assert name == AnonymousName.generate(post)
    assert name =~ ~r/^Background Pony #[0-9A-F]{4}$/

    refute name == AnonymousName.generate(%{post | topic_id: 13})
  end

  test "reveals an anonymously posting user's name only when requested" do
    user = confirmed_user_fixture()
    post = %Post{topic_id: 12, user_id: user.id, user: user, anonymous: true}

    assert AnonymousName.name(post) =~ ~r/^Background Pony #[0-9A-F]{4}$/
    assert AnonymousName.generate(post, true) =~ "#{user.name} (#"
    assert AnonymousName.generate(post, true) =~ ", hidden)"
  end

  test "returns the account name for a non-anonymous attribution" do
    user = confirmed_user_fixture()
    post = %Post{topic_id: 12, user_id: user.id, user: user, anonymous: false}

    assert AnonymousName.name(post) == user.name
  end
end
