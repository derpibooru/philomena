defmodule PhilomenaWeb.LayoutView do
  use PhilomenaWeb, :view

  def render_time(conn) do
    (Time.diff(Time.utc_now(), conn.assigns[:start_time], :microsecond) / 1000.0)
    |> Float.round(3)
    |> Float.to_string()
  end

  def hostname() do
    {:ok, host} = :inet.gethostname()
    
    host |> to_string
  end
end
