defmodule PhilomenaWeb.FilterJson do
  def as_json(filter) do
    %{
      id: filter.id,
      name: filter.name,
      description: filter.description,
      public: filter.public,
      system: filter.system,
      user_count: filter.user_count,
      user_id: filter.user_id,
      hidden_tag_ids: filter.hidden_tag_ids,
      spoilered_tag_ids: filter.spoilered_tag_ids,
      hidden_complex: filter.hidden_complex_str,
      spoilered_complex: filter.spoilered_complex_str
    }
  end
end
