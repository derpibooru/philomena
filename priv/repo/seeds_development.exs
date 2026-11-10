# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Philomena.Repo.insert!(%Philomena.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Philomena.{Repo, Forums.Forum, Users, Users.User}
alias Philomena.Comments
alias Philomena.Comments.Comment
alias Philomena.Images
alias Philomena.Topics
alias Philomena.Posts
alias Philomena.RateLimiter

{:ok, ip} = EctoNetwork.INET.cast({203, 0, 113, 0})
{:ok, _} = Application.ensure_all_started(:plug)

resources =
  "priv/repo/seeds_development.json"
  |> File.read!()
  |> JSON.decode!()

initial_actor = %Philomena.Attribution.Actor{
  ip: {127, 0, 0, 1},
  fingerprint: "d123456789abcde"
}

IO.puts("---- Generating users")

for user_def <- resources["users"] do
  {:ok, user} = Users.create_registration(initial_actor, user_def)

  user
  |> Repo.preload([:roles])
  |> User.confirm_changeset()
  |> User.update_changeset(%{role: user_def["role"]}, [])
  |> Repo.update!()
end

pleb = Repo.get_by!(User, name: "Pleb")
admin = Repo.get_by!(User, name: "Administrator")

pleb_actor = %Philomena.Attribution.Actor{
  user: pleb,
  ip: ip,
  fingerprint: "c1836832948",
  ban: nil
}

admin_actor = %Philomena.Attribution.Actor{
  user: admin,
  ip: ip,
  fingerprint: "c1836832948",
  ban: nil
}

IO.puts("---- Generating images")

for image_def <- resources["remote_images"] do
  file = Briefly.create!(extname: ".png")
  now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

  IO.puts("Fetching #{image_def["url"]} ...")
  {:ok, %{body: body, status: 200}} = PhilomenaProxy.Http.get(image_def["url"])

  File.write!(file, body)

  upload = %PhilomenaMedia.Upload{
    path: file,
    filename: "fixtures-#{now}"
  }

  IO.puts("Inserting ...")

  Images.create_image(
    pleb_actor,
    image_def,
    upload
  )
  |> case do
    {:ok, image} ->
      Images.create_image_approve(admin_actor, image.id)

      IO.puts("Created image ##{image.id}")

    {:error, :image, changeset, _so_far} ->
      IO.inspect(changeset.errors)
  end

  RateLimiter.reset_limits_globally!()
end

IO.puts("---- Generating comments for image #1")

for comment_body <- resources["comments"] do
  image_id = 1

  Comments.create_comment(
    pleb_actor,
    image_id,
    %{"body" => comment_body}
  )
  |> case do
    {:ok, %Comment{} = comment} ->
      Comments.create_comment_approve(admin_actor, image_id, comment.id)

    {:error, :comment, changeset, _so_far} ->
      IO.inspect(changeset.errors)
  end

  RateLimiter.reset_limits_globally!()
end

IO.puts("---- Generating forum posts")

for %{"forum" => forum_name, "topics" => topics} <- resources["forum_posts"] do
  forum = Repo.get_by!(Forum, short_name: forum_name)

  for %{"title" => topic_name, "posts" => [first_post | posts]} <- topics do
    Topics.create_topic(
      pleb_actor,
      forum.short_name,
      %{
        "title" => topic_name,
        "posts" => %{
          "0" => %{
            "body" => first_post
          }
        }
      }
    )
    |> case do
      {:ok, %{topic: topic}} ->
        for post <- posts do
          Posts.create_post(
            pleb_actor,
            forum.short_name,
            topic.slug,
            %{"body" => post}
          )
          |> case do
            {:ok, post} ->
              Posts.create_post_approve(
                admin_actor,
                forum.short_name,
                topic.slug,
                post.id
              )

            {:error, forum, topic} ->
              IO.inspect({forum.short_name, topic.slug})
          end

          RateLimiter.reset_limits_globally!()
        end

      {:error, :topic, changeset, _so_far} ->
        IO.inspect(changeset.errors)
    end

    RateLimiter.reset_limits_globally!()
  end
end

IO.puts("---- Done.")
