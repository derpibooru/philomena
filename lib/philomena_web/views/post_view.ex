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
    cond do
      Attribution.anonymous?(object) || !object.user ->
        PhilomenaWeb.UserAttributionView.anonymous_name(object)

      true ->
        object.user.name
    end
  end
end
