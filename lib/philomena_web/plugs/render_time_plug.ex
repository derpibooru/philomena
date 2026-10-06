defmodule PhilomenaWeb.RenderTimePlug do
  import Plug.Conn

  # No options
  def init([]), do: false

  # Assign current time
  def call(conn, _opts) do
    conn
    |> assign(:start_time, Time.utc_now())
    |> register_before_send(fn conn ->
      now = Time.utc_now()
      diff = Time.diff(now, conn.assigns.start_time, :millisecond)

      put_resp_header(conn, "x-render-time", "#{diff}")
    end)
  end
end
