defmodule PhilomenaWeb.Api.Json.ArtistLinkView do
  use PhilomenaWeb, :view

  def render("artist_link.json", %{artist_link: %{public: false}}) do
    nil
  end

  def render("artist_link.json", %{artist_link: link}) do
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
