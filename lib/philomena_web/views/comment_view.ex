defmodule PhilomenaWeb.CommentView do
  use PhilomenaWeb, :view

  def staff?(%{role: role}), do: role != "user"
  def staff?(_), do: false
end
