defmodule PhilomenaWeb.Image.CommentView do
  use PhilomenaWeb, :view

  def anonymous_by_default?(conn) do
    conn.assigns.current_user.anonymous_by_default
  end

  @spec can_report?(Plug.Conn.t()) :: boolean()
  def can_report?(conn),
    do: can?(conn, :new, Philomena.Reports.Report)
end
