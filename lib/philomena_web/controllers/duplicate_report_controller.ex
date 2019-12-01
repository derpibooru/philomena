defmodule PhilomenaWeb.DuplicateReportController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  @valid_states ~W(open rejected accepted claimed)

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:create]
  plug :load_resource, model: DuplicateReport, only: [:show], preload: [:user, image: :tags, duplicate_of_image: :tags]

  def index(conn, params) do
    states =
      params["states"]
      |> wrap()
      |> Enum.filter(&Enum.member?(@valid_states, &1))

    duplicate_reports =
      DuplicateReport
      |> where([d], d.state in ^states)
      |> preload([:user, image: :tags, duplicate_of_image: :tags])
      |> order_by(desc: :created_at)
      |> Repo.paginate(conn.assigns.pagination)

    render(conn, "index.html", duplicate_reports: duplicate_reports, layout_class: "layout--wide")
  end

  def create(conn, %{"duplicate_report" => duplicate_report_params}) do
    attribution = conn.assigns.attribution
    source = Repo.get!(Image, duplicate_report_params["image_id"])
    target = Repo.get!(Image, duplicate_report_params["duplicate_of_image_id"])

    case DuplicateReports.create_duplicate_report(source, target, attribution, duplicate_report_params) do
      {:ok, duplicate_report} ->
        conn
        |> put_flash(:info, "Duplicate report created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, duplicate_report.image_id))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to submit duplicate report")
        |> redirect(external: conn.assigns.referrer)
    end
  end

  def show(conn, _params) do
    dr = conn.assigns.duplicate_report

    render(conn, "show.html", duplicate_report: dr, layout_class: "layout--wide")
  end

  defp wrap(list) when is_list(list), do: list
  defp wrap(not_a_list), do: [not_a_list]
end
