defmodule PhilomenaWeb.LinksJson do
  def as_json(_conn, %{public: false}), do: nil

  def as_json(_conn, link) do
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
