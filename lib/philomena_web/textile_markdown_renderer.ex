defmodule PhilomenaWeb.TextileMarkdownRenderer do
  alias Philomena.Textile.ParserMarkdown

  def render_one(post, conn) do
    hd(render_collection([post], conn))
  end

  def render_collection(posts, conn) do
    opts = %{image_transform: &Camo.Image.image_url/1}
    parsed = Enum.map(posts, &ParserMarkdown.parse(opts, &1.body))

    parsed
    |> Enum.map(fn tree ->
      tree
      |> Enum.map(fn
        {_k, text} ->
          text
      end)
      |> Enum.join()
    end)
  end
end
