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

alias Philomena.{
  Repo,
  Comments.Comment,
  Filters.Filter,
  Forums.Forum,
  Galleries.Gallery,
  Posts.Post,
  Images.Image,
  Reports.Report,
  Filters.Filter,
  Roles.Role,
  Tags.Tag,
  Users.User,
  StaticPages.StaticPage
}

alias Philomena.Elasticsearch
alias Philomena.Users
alias Philomena.Tags
alias Philomena.Filters
import Ecto.Query

IO.puts("---- Creating Elasticsearch indices")

for model <- [Image, Comment, Gallery, Tag, Post, Report, Filter] do
  Elasticsearch.delete_index!(model)
  Elasticsearch.create_index!(model)
end

resources =
  "priv/repo/seeds.json"
  |> File.read!()
  |> Jason.decode!()

IO.puts("---- Generating rating tags")

for tag_name <- resources["rating_tags"] do
  %Tag{category: "rating"}
  |> Tag.creation_changeset(%{name: tag_name})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating system filters")

for filter_def <- resources["system_filters"] do
  spoilered_tag_list = Enum.join(filter_def["spoilered"], ",")
  hidden_tag_list = Enum.join(filter_def["hidden"], ",")

  %Filter{system: true}
  |> Filter.changeset(%{
    name: filter_def["name"],
    description: filter_def["description"],
    spoilered_tag_list: spoilered_tag_list,
    hidden_tag_list: hidden_tag_list
  })
  |> Repo.insert(on_conflict: :nothing)
  |> case do
    {:ok, filter} ->
      Filters.reindex_filter(filter)

    {:error, changeset} ->
      IO.inspect(changeset.errors)
  end
end

IO.puts("---- Generating forums")

for forum_def <- resources["forums"] do
  %Forum{}
  |> Forum.changeset(forum_def)
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating users")

for user_def <- resources["users"] do
  {:ok, user} = Users.register_user(user_def)

  user
  |> Repo.preload([:roles])
  |> User.confirm_changeset()
  |> User.update_changeset(%{role: user_def["role"]}, [])
  |> Repo.update!()
end

IO.puts("---- Generating roles")

for role_def <- resources["roles"] do
  %Role{name: role_def["name"], resource_type: role_def["resource_type"]}
  |> Role.changeset(%{})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating static pages")

for page_def <- resources["pages"] do
  %StaticPage{title: page_def["title"], slug: page_def["slug"], body: page_def["body"]}
  |> StaticPage.changeset(%{})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Indexing content")
Elasticsearch.reindex(Tag |> preload(^Tags.indexing_preloads()), Tag)

IO.puts("---- Done.")
