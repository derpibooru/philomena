defmodule PhilomenaWeb.PostView do
  alias Philomena.Attribution
  alias Textile.Parser

  use PhilomenaWeb, :view

  def textile_safe_author(object) do
    author_name = author_name(object)

    Parser.parse(%Parser{image_transform: & &1}, author_name)
    |> case do
      [{:text, ^author_name}] ->
        author_name

      _ ->
        # Cover *all* possibilities.
        literal =
          author_name
          |> String.replace("==]", "==]==][==")

        "[==#{literal}==]"
    end
  end

  defp author_name(object) do
    case Attribution.anonymous?(object) do
      true  -> PhilomenaWeb.UserAttributionView.anonymous_name(object)
      false -> object.user.name
    end
  end
end
