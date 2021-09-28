defmodule Philomena.MarkdownWriter do
  import Ecto.Changeset
  alias PhilomenaWeb.TextileMarkdownRenderer

  def put_markdown(obj, attrs, field, field_md) do
    val = attrs[field] || attrs[to_string(field)] || ""
    md = TextileMarkdownRenderer.render_one(%{body: val})
  
    obj
    |> put_change(field_md, md)
  end
end
