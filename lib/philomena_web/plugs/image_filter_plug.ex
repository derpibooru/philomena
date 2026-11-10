defmodule PhilomenaWeb.ImageFilterPlug do
  import Plug.Conn
  alias Philomena.Filters

  # No options
  def init([]), do: false

  # Assign current filter
  def call(conn, _opts) do
    image_filter =
      Filters.compile_image_filter(
        conn.assigns.actor,
        conn.assigns[:current_filter],
        conn.assigns[:forced_filter]
      )

    assign(conn, :image_filter, image_filter)
  end
end
