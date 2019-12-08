defmodule PhilomenaWeb.Admin.ReportView do
  use PhilomenaWeb, :view

  import PhilomenaWeb.ReportView, only: [link_to_reported_thing: 2, report_row_class: 1, pretty_state: 1]
  import PhilomenaWeb.ProfileView, only: [user_abbrv: 1, current?: 2]

  def truncate(<<string::binary-size(50), _rest::binary>>), do: string <> "..."
  def truncate(string), do: string

  def truncated_ip_link(conn, ip) do
    case to_string(ip) do
      <<string::binary-size(25), _rest::binary>> = ip ->
        link(string <> "...", to: Routes.ip_profile_path(conn, :show, ip))

      ip ->
        link(ip, to: Routes.ip_profile_path(conn, :show, ip))
    end
  end

  def ordered_tags(tags) do
    Enum.sort_by(tags, & &1.name)
  end
end
