defmodule PhilomenaWeb.StatView do
  use PhilomenaWeb, :view

  def upload_graph(data) do
    data = Enum.sort_by(data, & &1["key"])
    n_buckets = length(data)

    {%{"key" => min_time}, %{"key" => max_time}} = Enum.min_max_by(data, & &1["key"], fn -> %{"key" => 0} end)
    {%{"doc_count" => min_docs}, %{"doc_count" => max_docs}} = Enum.min_max_by(data, & &1["doc_count"], fn -> %{"doc_count" => 0} end)

    graph_width = 950
    graph_height = 475

    bar_width = safe_div(graph_width, n_buckets)
    max_bar_height = safe_div(graph_height, max_docs - min_docs)

    content_tag :svg, class: "upload-stats", viewBox: "0 0 #{graph_width} #{graph_height}" do
      for {datum, i} <- Enum.with_index(data) do
        bar_height = safe_div(datum["doc_count"], max_docs) * max_bar_height

        x = i * bar_width
        y = graph_height-bar_height
        height = bar_height

        content_tag :rect, width: bar_width, height: height, x: x, y: y, fill: "#000" do
          content_tag :title, "#{datum["key_as_string"]} - #{datum["doc_count"]} uploads"
        end
      end
    end
  end

  defp safe_div(n, 0), do: 0
  defp safe_div(n, d), do: n / d
end
