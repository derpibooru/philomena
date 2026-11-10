defmodule PhilomenaWeb.PostView do
  alias Philomena.Attribution
  alias Philomena.Attribution.AnonymousName

  use PhilomenaWeb, :view

  def markdown_safe_author(object) do
    Philomena.Markdown.escape("@" <> author_name(object))
  end

  defp author_name(object) do
    if Attribution.anonymous?(object) || !object.user do
      AnonymousName.generate(object)
    else
      object.user.name
    end
  end
end
