defmodule PhilomenaWeb.Admin.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Search
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Reports.Report
  alias Philomena.Reports.Query
  alias Philomena.Polymorphic
  alias Philomena.ModNotes.ModNote
  alias Philomena.ModNotes
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  plug :load_and_authorize_resource,
    model: Report,
    only: [:show],
    preload: [:admin, user: [:linked_tags, awards: :badge]]

  plug :set_mod_notes when action in [:show]

  def index(conn, %{"rq" => query_string}) do
    {:ok, query} = Query.compile(query_string)

    reports = load_reports(conn, query)

    render(conn, "index.html",
      title: "Admin - Reports",
      layout_class: "layout--wide",
      reports: reports,
      my_reports: [],
      system_reports: []
    )
  end

  def index(conn, _params) do
    user = conn.assigns.current_user

    query = %{
      bool: %{
        should: [
          %{term: %{open: false}},
          %{
            bool: %{
              must: %{term: %{open: true}},
              must_not: [
                %{term: %{admin_id: user.id}},
                %{term: %{system: true}}
              ]
            }
          }
        ]
      }
    }

    reports = load_reports(conn, query)

    my_reports =
      Report
      |> where(open: true, admin_id: ^user.id)
      |> preload([:admin, user: :linked_tags])
      |> order_by(desc: :created_at)
      |> Repo.all()
      |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])

    system_reports =
      Report
      |> where(open: true, system: true)
      |> preload([:admin, user: :linked_tags])
      |> order_by(desc: :created_at)
      |> Repo.all()
      |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])

    render(conn, "index.html",
      title: "Admin - Reports",
      layout_class: "layout--wide",
      reports: reports,
      my_reports: my_reports,
      system_reports: system_reports
    )
  end

  def show(conn, _params) do
    [report] =
      Polymorphic.load_polymorphic([conn.assigns.report],
        reportable: [reportable_id: :reportable_type]
      )

    body = MarkdownRenderer.render_one(%{body: report.reason}, conn)

    render(conn, "show.html", title: "Showing Report", report: report, body: body)
  end

  defp load_reports(conn, query) do
    reports =
      Report
      |> Search.search_definition(
        %{
          query: query,
          sort: sorts()
        },
        conn.assigns.pagination
      )
      |> Search.search_records(preload(Report, [:admin, user: :linked_tags]))

    entries = Polymorphic.load_polymorphic(reports, reportable: [reportable_id: :reportable_type])

    %{reports | entries: entries}
  end

  defp sorts do
    [
      %{open: :desc},
      %{state: :desc},
      %{created_at: :desc}
    ]
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, Report) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp set_mod_notes(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, ModNote) do
      report = conn.assigns.report

      renderer = &MarkdownRenderer.render_collection(&1, conn)
      mod_notes = ModNotes.list_all_mod_notes_by_type_and_id("Report", report.id, renderer)
      assign(conn, :mod_notes, mod_notes)
    else
      conn
    end
  end
end
