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
  Filters.Filter,
  Forums.Forum,
  Roles.Role,
  Tags.Tag,
  Users.User,
  StaticPages.StaticPage,
  Rules.Rule,
  Rules.RuleVersion
}

alias PhilomenaQuery.Search
alias Philomena.Users
alias Philomena.Tags
alias Philomena.Filters
import Ecto.Query

IO.puts("---- Creating search indices")

Philomena.SearchMigrator.migrate_all(maintenance: false)

resources =
  "priv/repo/seeds.json"
  |> File.read!()
  |> JSON.decode!()

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
  |> Filter.changeset(
    nil,
    %{
      name: filter_def["name"],
      description: filter_def["description"],
      spoilered_tag_list: spoilered_tag_list,
      hidden_tag_list: hidden_tag_list
    }
  )
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

IO.puts("---- Generating the admin user")

user_def = %{
  "name" => System.get_env("ADMIN_USERNAME", "Administrator"),
  "email" => System.get_env("ADMIN_EMAIL", "admin@example.com"),
  "password" => System.get_env("ADMIN_PASSWORD", "philomena123"),
  "role" => "admin"
}

initial_actor = %Philomena.Attribution.Actor{
  ip: {127, 0, 0, 1},
  fingerprint: "d123456789abcde"
}

{:ok, user} = Users.create_registration(initial_actor, user_def)

user
|> Repo.preload([:roles])
|> User.confirm_changeset()
|> User.update_changeset(%{role: user_def["role"]}, [])
|> Repo.update!()

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

IO.puts("---- Generating rules and initial versions")

for rule_def <- resources["rules"] do
  {:ok, rule} =
    %Rule{}
    |> Rule.changeset(%{
      name: rule_def["name"],
      title: Map.get(rule_def, "title", ""),
      description: Map.get(rule_def, "description", ""),
      short_description: Map.get(rule_def, "short_description", ""),
      example: Map.get(rule_def, "example", ""),
      position: Map.get(rule_def, "position", 1),
      highlight: Map.get(rule_def, "highlight", false),
      hidden: Map.get(rule_def, "hidden", false),
      internal: Map.get(rule_def, "internal", false)
    })
    |> Repo.insert(on_conflict: :nothing)

  %RuleVersion{}
  |> RuleVersion.changeset(%{
    name: rule_def["name"],
    title: Map.get(rule_def, "title", ""),
    description: Map.get(rule_def, "description", ""),
    short_description: Map.get(rule_def, "short_description", ""),
    example: Map.get(rule_def, "example", ""),
    rule_id: rule.id,
    user_id: nil
  })
  |> Repo.insert()
end

IO.puts("---- Indexing content")
Search.reindex(Tag |> preload(^Tags.indexing_preloads()), Tag)

IO.puts("---- Done.")
