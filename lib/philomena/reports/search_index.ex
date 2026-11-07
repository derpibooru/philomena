defmodule Philomena.Reports.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def version do
    1
  end

  @impl true
  def index_name do
    "reports"
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
          image_id: %{type: "keyword"},
          created_at: %{type: "date"},
          ip: %{type: "ip"},
          fingerprint: %{type: "keyword"},
          state: %{type: "keyword"},
          user: %{type: "keyword"},
          user_id: %{type: "keyword"},
          admin: %{type: "keyword"},
          admin_id: %{type: "keyword"},
          reportable_type: %{type: "keyword"},
          reportable_id: %{type: "keyword"},
          open: %{type: "boolean"},
          reason: %{type: "text", analyzer: "snowball"},
          system: %{type: "boolean"},
          related_user_ids: %{type: "keyword"},
          related_users: %{type: "keyword"}
        }
      }
    }
  end

  @impl true
  def as_json(report) do
    related_users = related_users(report) |> Enum.reject(&is_nil/1)

    %{
      id: report.id,
      image_id: image_id(report),
      created_at: report.created_at,
      ip: to_string(report.ip),
      state: report.state,
      user: if(report.user, do: String.downcase(report.user.name)),
      user_id: report.user_id,
      admin: if(report.admin, do: String.downcase(report.admin.name)),
      admin_id: report.admin_id,
      reportable_type: reportable_type(report),
      reportable_id: reportable_id(report),
      fingerprint: report.fingerprint,
      open: report.open,
      reason: report.reason,
      system: report.system,
      related_user_ids: related_users |> Enum.map(& &1.id),
      related_users: related_users |> Enum.map(&String.downcase(&1.name))
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{
        bool: %{
          should: [
            %{term: %{user: old_name}},
            %{term: %{admin: old_name}},
            %{term: %{related_users: old_name}}
          ]
        }
      },
      replacements: [
        %{path: ["user"], old: old_name, new: new_name},
        %{path: ["admin"], old: old_name, new: new_name}
      ],
      set_replacements: [%{path: ["related_users"], old: old_name, new: new_name}]
    }
  end

  # The document keeps the `reportable_type`/`reportable_id` pair the search
  # syntax queries against; both are derived from whichever target foreign key
  # column is set.
  defp reportable_type(report) do
    cond do
      report.image_id -> "Image"
      report.comment_id -> "Comment"
      report.post_id -> "Post"
      report.reported_user_id -> "User"
      report.commission_id -> "Commission"
      report.conversation_id -> "Conversation"
      report.gallery_id -> "Gallery"
      true -> nil
    end
  end

  defp reportable_id(report) do
    report.image_id || report.comment_id || report.post_id || report.reported_user_id ||
      report.commission_id || report.conversation_id || report.gallery_id
  end

  defp image_id(%{image_id: image_id}) when not is_nil(image_id), do: image_id
  defp image_id(%{comment: %{image_id: image_id}}), do: image_id
  defp image_id(_report), do: nil

  defp related_users(%{reported_user_id: id, reported_user: user}) when not is_nil(id),
    do: [user]

  defp related_users(%{image_id: id, image: %{user: user}}) when not is_nil(id), do: [user]

  defp related_users(%{comment_id: id, comment: %{user: user}}) when not is_nil(id), do: [user]

  defp related_users(%{gallery_id: id, gallery: %{user: user}}) when not is_nil(id), do: [user]

  defp related_users(%{conversation_id: id, conversation: %{from: from, to: to}})
       when not is_nil(id),
       do: [from, to]

  defp related_users(%{post_id: id, post: %{user: user}}) when not is_nil(id), do: [user]

  defp related_users(%{commission_id: id, commission: %{user: user}}) when not is_nil(id),
    do: [user]

  defp related_users(_report), do: []
end
