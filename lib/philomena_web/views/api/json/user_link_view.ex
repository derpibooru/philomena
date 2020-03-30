defmodule PhilomenaWeb.Api.Json.UserLinkView do
  use PhilomenaWeb, :view

  def render("user_link.json", %{user_link: %{public: false}}) do
    nil
  end

  def render("user_link.json", %{user_link: link}) do
    %{
      user_id: link.user_id,
      created_at: link.created_at,
      state: link.aasm_state,
      tag_id: tag_id(link.tag)
    }
  end

  defp tag_id(nil) do
    nil
  end

  defp tag_id(tag) do
    tag.id
  end
end
