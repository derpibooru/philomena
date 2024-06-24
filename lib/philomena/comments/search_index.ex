defmodule Philomena.Comments.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def index_name do
    "comments"
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
          posted_at: %{type: "date"},
          ip: %{type: "ip"},
          fingerprint: %{type: "keyword"},
          image_id: %{type: "keyword"},
          user_id: %{type: "keyword"},
          author: %{type: "keyword"},
          image_tag_ids: %{type: "keyword"},
          # boolean
          anonymous: %{type: "keyword"},
          # boolean
          hidden_from_users: %{type: "keyword"},
          body: %{type: "text", analyzer: "snowball"},
          approved: %{type: "boolean"}
        }
      }
    }
  end

  @impl true
  def as_json(comment) do
    %{
      id: comment.id,
      posted_at: comment.created_at,
      ip: comment.ip |> to_string,
      fingerprint: comment.fingerprint,
      image_id: comment.image_id,
      user_id: comment.user_id,
      author: if(!!comment.user and !comment.anonymous, do: comment.user.name),
      image_tag_ids: comment.image.tags |> Enum.map(& &1.id),
      anonymous: comment.anonymous,
      hidden_from_users: comment.image.hidden_from_users || comment.hidden_from_users,
      body: comment.body,
      approved: comment.image.approved && comment.approved
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    %{
      query: %{term: %{author: old_name}},
      replacements: [%{path: ["author"], old: old_name, new: new_name}],
      set_replacements: []
    }
  end
end
