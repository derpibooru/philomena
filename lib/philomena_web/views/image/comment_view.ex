defmodule PhilomenaWeb.Image.CommentView do
  use PhilomenaWeb, :view

  def anonymous_by_default?(conn) do
    conn.assigns.current_user.anonymous_by_default
  end
end
