defmodule PhilomenaWeb.Admin.ApprovalView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.Admin.ReportView

  # Shamelessly copied from ReportView
  def truncated_ip_link(conn, ip), do: ReportView.truncated_ip_link(conn, ip)

  def image_thumb(conn, image) do
    render(PhilomenaWeb.ImageView, "_image_container.html",
      image: image,
      size: :thumb_tiny,
      conn: conn
    )
  end
end
