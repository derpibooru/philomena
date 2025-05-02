defmodule PhilomenaWeb.PostView do
  alias Philomena.Attribution

  use PhilomenaWeb, :view

  def markdown_safe_author(object) do
    Philomena.Markdown.escape("@" <> author_name(object))
  end

  defp author_name(object) do
    if Attribution.anonymous?(object) || !object.user do
      PhilomenaWeb.UserAttributionView.anonymous_name(object)
    else
      object.user.name
    end
  end
end
