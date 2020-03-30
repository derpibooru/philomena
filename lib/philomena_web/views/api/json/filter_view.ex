defmodule PhilomenaWeb.Api.Json.FilterView do
  use PhilomenaWeb, :view

  def render("index.json", %{filters: filters, total: total} = assigns) do
    %{
      filters: render_many(filters, PhilomenaWeb.Api.Json.FilterView, "filter.json", assigns),
      total: total
    }
  end

  def render("show.json", %{filter: filter} = assigns) do
    %{filter: render_one(filter, PhilomenaWeb.Api.Json.FilterView, "filter.json", assigns)}
  end

  def render("filter.json", %{filter: filter}) do
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
