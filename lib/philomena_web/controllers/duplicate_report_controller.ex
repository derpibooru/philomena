defmodule PhilomenaWeb.DuplicateReportController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  @valid_states ~W(open rejected accepted claimed)

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]

  plug :load_resource,
    model: DuplicateReport,
    only: [:show],
    preload: [:image, :duplicate_of_image]

  def index(conn, params) do
    states =
      (presence(params["states"]) || ~W(open claimed))
      |> wrap()
      |> Enum.filter(&Enum.member?(@valid_states, &1))

    duplicate_reports =
      DuplicateReport
      |> where([d], d.state in ^states)
      |> preload([:user, :modifier, image: [:user, :tags], duplicate_of_image: [:user, :tags]])
      |> order_by(desc: :created_at)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Duplicate Reports",
      duplicate_reports: duplicate_reports,
      layout_class: "layout--wide"
    )
  end

  def create(conn, %{"duplicate_report" => duplicate_report_params}) do
    attributes = conn.assigns.attributes
    source = Repo.get!(Image, duplicate_report_params["image_id"])
    target = Repo.get!(Image, duplicate_report_params["duplicate_of_image_id"])

    case DuplicateReports.create_duplicate_report(
           source,
           target,
           attributes,
           duplicate_report_params
         ) do
      {:ok, duplicate_report} ->
        conn
        |> put_flash(:info, "Duplicate report created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, duplicate_report.image_id))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to submit duplicate report")
        |> redirect(to: Routes.image_path(conn, :show, source))
    end
  end

  def show(conn, _params) do
    dr = conn.assigns.duplicate_report

    render(conn, "show.html",
      title: "Showing Duplicate Report",
      duplicate_report: dr,
      layout_class: "layout--wide"
    )
  end

  defp wrap(list) when is_list(list), do: list
  defp wrap(not_a_list), do: [not_a_list]
  defp presence(""), do: nil
  defp presence(x), do: x
end
