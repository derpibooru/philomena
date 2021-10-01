defmodule PhilomenaWeb.MarkdownView do
  use PhilomenaWeb, :view

  def anonymous_by_default?(conn) do
    conn.assigns.current_user.anonymous_by_default
  end

  def required?(required) when required == false, do: nil
  def required?(_), do: true

  def add_classes(base_classes, new_classes) when is_binary(new_classes), do: "#{base_classes} #{new_classes}"
  def add_classes(base_classes, _), do: base_classes
end
