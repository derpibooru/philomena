defmodule Philomena.Reports.ElasticsearchIndex do
  @behaviour Philomena.ElasticsearchIndex

  @impl true
  def index_name do
    "reports"
  end

  @impl true
  def doc_type do
    "report"
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
        report: %{
          _all: %{enabled: false},
          dynamic: false,
          properties: %{
            id: %{type: "integer"},
            image_id: %{type: "integer"},
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
            reason: %{type: "text", analyzer: "snowball"}
          }
        }
      }
    }
  end

  @impl true
  def as_json(report) do
    %{
      id: report.id,
      image_id: image_id(report),
      created_at: report.created_at,
      ip: report.ip |> to_string(),
      state: report.state,
      user: if(report.user, do: String.downcase(report.user.name)),
      user_id: report.user_id,
      admin: if(report.admin, do: String.downcase(report.admin.name)),
      admin_id: report.admin_id,
      reportable_type: report.reportable_type,
      reportable_id: report.reportable_id,
      fingerprint: report.fingerprint,
      open: report.open,
      reason: report.reason
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
            %{term: %{admin: old_name}}
          ]
        }
      },
      replacements: [
        %{path: ["user"], old: old_name, new: new_name},
        %{path: ["admin"], old: old_name, new: new_name}
      ],
      set_replacements: []
    }
  end

  defp image_id(%{reportable_type: "Image", reportable_id: image_id}), do: image_id
  defp image_id(%{reportable_type: "Comment", reportable: %{image_id: image_id}}), do: image_id
  defp image_id(_report), do: nil
end
