defmodule PhilomenaWeb.MarkdownView do
  use PhilomenaWeb, :view

  def anonymous_by_default?(conn) do
    conn.assigns.current_user.anonymous_by_default
  end

  def required?(%{assigns: %{required: false}}), do: nil
  def required?(_), do: true
end
