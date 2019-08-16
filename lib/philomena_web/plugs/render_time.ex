defmodule PhilomenaWeb.Plugs.RenderTime do
  import Plug.Conn

  # No options
  def init([]), do: false

  # Assign current time
  def call(conn, _opts) do
    conn |> assign(:start_time, Time.utc_now())
  end
end
