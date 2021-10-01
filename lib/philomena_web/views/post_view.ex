defmodule PhilomenaWeb.PostView do
  alias Philomena.Attribution

  use PhilomenaWeb, :view

  def markdown_safe_author(object) do
    Philomena.Markdown.escape("@" <> author_name(object))
  end

  defp author_name(object) do
    cond do
      Attribution.anonymous?(object) || !object.user ->
        PhilomenaWeb.UserAttributionView.anonymous_name(object)

      true ->
        object.user.name
    end
  end
end
