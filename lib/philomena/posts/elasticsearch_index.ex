defmodule Philomena.Posts.ElasticsearchIndex do
  @behaviour Philomena.ElasticsearchIndex

  @impl true
  def index_name do
    "posts"
  end

  @impl true
  def mapping do
    %{
      settings: %{
        index: %{
          number_of_shards: 5,
          max_result_window: 10_000_000
        }
      },
      mappings: %{
        dynamic: false,
        properties: %{
          id: %{type: "integer"},
          body: %{type: "text", analyzer: "snowball"},
          ip: %{type: "ip"},
          user_agent: %{type: "keyword"},
          referrer: %{type: "keyword"},
          fingerprint: %{type: "keyword"},
          subject: %{type: "text", analyzer: "snowball"},
          author: %{type: "keyword"},
          topic_position: %{type: "integer"},
          forum_id: %{type: "keyword"},
          topic_id: %{type: "keyword"},
          user_id: %{type: "keyword"},
          anonymous: %{type: "boolean"},
          updated_at: %{type: "date"},
          created_at: %{type: "date"},
          deleted: %{type: "boolean"},
          access_level: %{type: "keyword"},
          destroyed_content: %{type: "boolean"}
        }
      }
    }
  end

  @impl true
  def as_json(post) do
    %{
      id: post.id,
      topic_id: post.topic_id,
      body: post.body,
      author: if(!!post.user and !post.anonymous, do: String.downcase(post.user.name)),
      subject: post.topic.title,
      ip: post.ip |> to_string(),
      user_agent: post.user_agent,
      referrer: post.referrer,
      fingerprint: post.fingerprint,
      topic_position: post.topic_position,
      forum_id: post.topic.forum_id,
      user_id: post.user_id,
      anonymous: post.anonymous,
      created_at: post.created_at,
      updated_at: post.updated_at,
      deleted: post.hidden_from_users,
      access_level: post.topic.forum.access_level,
      destroyed_content: post.destroyed_content
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{term: %{author: old_name}},
      replacements: [%{path: ["author"], old: old_name, new: new_name}],
      set_replacements: []
    }
  end
end
