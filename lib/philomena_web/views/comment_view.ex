defmodule PhilomenaWeb.CommentView do
  use PhilomenaWeb, :view

  @spec can_report?(Plug.Conn.t()) :: boolean()
  def can_report?(conn),
    do: can?(conn, :new, Philomena.Reports.Report)
end
