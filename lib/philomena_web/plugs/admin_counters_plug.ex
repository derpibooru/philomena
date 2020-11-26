defmodule PhilomenaWeb.AdminCountersPlug do
  @moduledoc """
  This plug stores the counts used by the admin bar.
  ## Example
      plug PhilomenaWeb.AdminCountersPlug
  """

  alias Philomena.DuplicateReports
  alias Philomena.Reports
  alias Philomena.ArtistLinks
  alias Philomena.DnpEntries

  import Plug.Conn, only: [assign: 3]

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t()) :: Plug.Conn.t()
  def call(conn), do: call(conn, nil)

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    user = conn.assigns.current_user

    maybe_assign_admin_metrics(conn, user, staff?(user))
  end

  defp maybe_assign_admin_metrics(conn, _user, false), do: conn

  defp maybe_assign_admin_metrics(conn, user, true) do
    duplicate_reports = DuplicateReports.count_duplicate_reports(user)
    reports = Reports.count_reports(user)
    artist_links = ArtistLinks.count_artist_links(user)
    dnps = DnpEntries.count_dnp_entries(user)

    conn
    |> assign(:duplicate_report_count, duplicate_reports)
    |> assign(:report_count, reports)
    |> assign(:artist_link_count, artist_links)
    |> assign(:dnp_entry_count, dnps)
  end

  defp staff?(%{role: role}) when role in ["assistant", "moderator", "admin"], do: true
  defp staff?(_user), do: false
end
