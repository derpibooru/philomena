defmodule PhilomenaWeb.CommentView do
  use PhilomenaWeb, :view

  defp comment_body_class(%{destroyed_content: true}), do: "comment--destroyed"
  defp comment_body_class(_comment), do: nil
end
