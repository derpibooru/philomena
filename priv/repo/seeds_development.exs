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
alias Philomena.Images
alias Philomena.Topics
alias Philomena.Posts
alias Philomena.Tags

{:ok, ip} = EctoNetwork.INET.cast({203, 0, 113, 0})
{:ok, _} = Application.ensure_all_started(:plug)

resources =
  "priv/repo/seeds_development.json"
  |> File.read!()
  |> JSON.decode!()

IO.puts "---- Generating users"
for user_def <- resources["users"] do
  {:ok, user} = Users.register_user(user_def)

  user
  |> Repo.preload([:roles])
  |> User.confirm_changeset()
  |> User.update_changeset(%{role: user_def["role"]}, [])
  |> Repo.update!()
end

pleb = Repo.get_by!(User, name: "Pleb")
request_attributes = [
  fingerprint: "c1836832948",
  ip: ip,
  user_id: pleb.id,
  user: pleb
]

IO.puts "---- Generating images"
for image_def <- resources["remote_images"] do
  file = Briefly.create!()
  now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

  IO.puts "Fetching #{image_def["url"]} ..."
  {:ok, %{body: body}} = PhilomenaProxy.Http.get(image_def["url"])

  File.write!(file, body)

  upload = %Plug.Upload{
    path: file,
    content_type: "application/octet-stream",
    filename: "fixtures-#{now}"
  }

  IO.puts "Inserting ..."

  Images.create_image(
    request_attributes,
    Map.merge(image_def, %{"image" => upload})
  )
  |> case do
    {:ok, %{image: image}} ->
      Images.approve_image(image)
      Images.reindex_image(image)
      Tags.reindex_tags(image.added_tags)

      IO.puts "Created image ##{image.id}"

    {:error, :image, changeset, _so_far} ->
      IO.inspect changeset.errors
  end
end

IO.puts "---- Generating comments for image #1"
for comment_body <- resources["comments"] do
  image = Images.get_image!(1)

  Comments.create_comment(
    image,
    request_attributes,
    %{"body" => comment_body}
  )
  |> case do
    {:ok, %{comment: comment}} ->
      Comments.approve_comment(comment, pleb)
      Comments.reindex_comment(comment)
      Images.reindex_image(image)

    {:error, :comment, changeset, _so_far} ->
      IO.inspect changeset.errors
  end
end

IO.puts "---- Generating forum posts"
for %{"forum" => forum_name, "topics" => topics} <- resources["forum_posts"] do
  forum = Repo.get_by!(Forum, short_name: forum_name)

  for %{"title" => topic_name, "posts" => [first_post | posts]} <- topics do
    Topics.create_topic(
      forum,
      request_attributes,
      %{
        "title" => topic_name,
        "posts" => %{
          "0" => %{
            "body" => first_post,
          }
        }
      }
    )
    |> case do
      {:ok, %{topic: topic}} ->
        for post <- posts do
          Posts.create_post(
            topic,
            request_attributes,
            %{"body" => post}
          )
          |> case do
            {:ok, %{post: post}} ->
              Posts.approve_post(post, pleb)
              Posts.reindex_post(post)

            {:error, :post, changeset, _so_far} ->
              IO.inspect changeset.errors
          end
        end

      {:error, :topic, changeset, _so_far} ->
        IO.inspect changeset.errors
    end
  end
end

IO.puts "---- Done."
