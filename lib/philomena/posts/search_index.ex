defmodule Philomena.Posts.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def version do
    1
  end

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
          fingerprint: %{type: "keyword"},
          subject: %{type: "text", analyzer: "snowball"},
          author_id: %{type: "keyword"},
          author: %{type: "keyword"},
          true_author_id: %{type: "keyword"},
          true_author: %{type: "keyword"},
          topic_position: %{type: "integer"},
          forum: %{type: "keyword"},
          forum_id: %{type: "keyword"},
          topic_id: %{type: "keyword"},
          anonymous: %{type: "boolean"},
          updated_at: %{type: "date"},
          created_at: %{type: "date"},
          hidden_from_users: %{type: "boolean"},
          access_level: %{type: "keyword"},
          destroyed_content: %{type: "boolean"},
          approved: %{type: "boolean"},
          deleted_by_user: %{type: "keyword"},
          deleted_by_user_id: %{type: "keyword"},
          deletion_reason: %{type: "text", analyzer: "snowball"}
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
      author_id: if(!post.anonymous, do: post.user_id),
      author: if(!!post.user and !post.anonymous, do: String.downcase(post.user.name)),
      true_author_id: post.user_id,
      true_author: if(!!post.user, do: String.downcase(post.user.name)),
      subject: post.topic.title,
      ip: to_string(post.ip),
      fingerprint: post.fingerprint,
      topic_position: post.topic_position,
      forum: post.topic.forum.short_name,
      forum_id: post.topic.forum_id,
      anonymous: post.anonymous,
      created_at: post.created_at,
      updated_at: post.updated_at,
      hidden_from_users: post.hidden_from_users or post.topic.hidden_from_users,
      access_level: post.topic.forum.access_level,
      destroyed_content: post.destroyed_content,
      approved: post.approved,
      deleted_by_user: if(!!post.deleted_by, do: String.downcase(post.deleted_by.name)),
      deleted_by_user_id: post.deleted_by_id,
      deletion_reason: post.deletion_reason
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{
        bool: %{
          should: [
            %{term: %{author: old_name}},
            %{term: %{true_author: old_name}},
            %{term: %{deleted_by_user: old_name}}
          ]
        }
      },
      replacements: [
        %{path: ["author"], old: old_name, new: new_name},
        %{path: ["true_author"], old: old_name, new: new_name},
        %{path: ["deleted_by_user"], old: old_name, new: new_name}
      ],
      set_replacements: []
    }
  end
end
