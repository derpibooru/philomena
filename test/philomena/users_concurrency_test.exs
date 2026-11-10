defmodule Philomena.UsersConcurrencyTest do
  use Philomena.ConcurrentDataCase

  import Ecto.Query
  import Philomena.UsersFixtures
  import Philomena.AttributionFixtures
  import Philomena.FiltersFixtures
  import Philomena.TagsFixtures

  alias Philomena.Repo
  alias Philomena.Tags
  alias Philomena.Users
  alias Philomena.Users.User

  test "concurrent registrations with the same email persist only one user" do
    email = unique_user_email()

    results =
      concurrently([
        fn ->
          Users.create_registration(actor(), %{
            name: "concurrent-registration-one",
            email: email,
            password: valid_user_password()
          })
        end,
        fn ->
          Users.create_registration(actor(), %{
            name: "concurrent-registration-two",
            email: email,
            password: valid_user_password()
          })
        end
      ])

    assert Enum.count(results, &match?({:ok, %User{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
    assert Repo.aggregate(from(user in User, where: user.email == ^email), :count) == 1
  end

  test "concurrent watched-tag updates preserve every tag" do
    user = confirmed_user_fixture()
    actor = actor(user)
    tags = Enum.map(1..8, fn _ -> tag_fixture() end)

    results = concurrently(for tag <- tags, do: fn -> Users.watch_tag(actor, tag) end)

    assert Enum.all?(results, &match?({:ok, %User{}}, &1))

    assert Repo.get!(User, user.id).watched_tag_ids |> Enum.sort() ==
             Enum.map(tags, & &1.id) |> Enum.sort()
  end

  test "concurrent failed attempts only allow ten attempts" do
    user = confirmed_user_fixture()

    results =
      concurrently(
        for _ <- 1..20 do
          fn -> Users.fetch_user_by_email_and_password(user.email, "invalid", & &1) end
        end
      )

    assert results == List.duplicate({:error, :not_found}, 20)

    user = Repo.get!(User, user.id)
    assert user.failed_attempts == 10
    assert user.locked_at
  end

  test "settings updates and watched-tag updates do not lose the serialized result" do
    user = confirmed_user_fixture()
    actor = actor(user)
    tag = tag_fixture()

    results =
      concurrently([
        fn -> Users.update_settings(actor, %{"watched_tag_list" => ""}) end,
        fn -> Users.watch_tag(actor, tag) end
      ])

    assert Enum.all?(results, &match?({:ok, %User{}}, &1))
    assert Repo.get!(User, user.id).watched_tag_ids in [[], [tag.id]]
  end

  test "watched-tag settings racing an alias store the canonical tag" do
    user = confirmed_user_fixture()
    source = tag_fixture(name: unique_tag_name())
    target = tag_fixture(name: unique_tag_name())

    results =
      concurrently([
        fn ->
          Tags.update_tag_alias(actor(admin_user_fixture()), source.slug, %{
            "target_tag" => target.name
          })
        end,
        fn -> Users.update_settings(actor(user), %{"watched_tag_list" => source.name}) end
      ])

    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert Repo.get!(User, user.id).watched_tag_ids == [target.id]
  end

  test "setting the current filter races safely with clearing recent filters" do
    user = confirmed_user_fixture()
    actor = actor(user)
    filter = filter_fixture(user)

    results =
      concurrently([
        fn -> Users.set_current_filter(user, filter) end,
        fn -> Users.delete_recent_filters(actor) end
      ])

    assert Enum.all?(results, &match?({:ok, %User{}}, &1))
    user = Repo.get!(User, user.id)
    assert user.current_filter_id in [nil, filter.id]
    assert user.recent_filter_ids in [[], [filter.id], [filter.id, nil], [nil]]
  end

  test "concurrent reactivation attempts validate the current state" do
    target = deactivated_user_fixture()
    slug = target.slug
    admin = actor(admin_user_fixture())

    results =
      concurrently([
        fn -> Users.create_user_activation(admin, slug) end,
        fn -> Users.create_user_activation(admin, slug) end
      ])

    assert Enum.count(results, &match?({:ok, %User{}}, &1)) == 1
  end

  test "concurrent deactivation attempts allow only the active transition" do
    target = confirmed_user_fixture()
    slug = target.slug
    admin = actor(admin_user_fixture())

    results =
      concurrently([
        fn -> Users.delete_user_activation(admin, slug) end,
        fn -> Users.delete_user_activation(admin, slug) end
      ])

    assert Enum.count(results, &match?({:ok, %User{}}, &1)) == 1
    assert Repo.get!(User, target.id).deleted_at
  end

  test "concurrent name changes allow only one rename within the rename window" do
    user = confirmed_user_fixture()
    actor = actor(user)

    results =
      concurrently([
        fn -> Users.update_name(actor, %{"name" => "first_concurrent_name"}) end,
        fn -> Users.update_name(actor, %{"name" => "second_concurrent_name"}) end
      ])

    assert Enum.count(results, &match?({:ok, %User{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, :unauthorized}, &1)) == 1
    assert Repo.get!(User, user.id).name in ["first_concurrent_name", "second_concurrent_name"]
  end
end
