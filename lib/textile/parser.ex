defmodule Textile.Parser do
  import Textile.ParserHelpers

  alias Textile.{
    Lexer,
    Parser,
    TokenCoalescer
  }

  defstruct [
    image_transform: nil
  ]

  def parse(%Parser{} = parser, input) do
    with {:ok, tokens, _1, _2, _3, _4} <- Lexer.lex(input |> remove_linefeeds()),
         tokens <- TokenCoalescer.coalesce_lex(tokens),
         {:ok, tree, []} <- textile_top(parser, tokens),
         tree <- TokenCoalescer.coalesce_parse(tree)
    do
      tree
    else
      err ->
        err
    end
  end


  #
  # Backtracking LL packrat parser for simplified Textile grammar
  #


  #
  # textile = (well_formed_including_paragraphs | TOKEN)*;
  #    
  defp textile_top(_parser, []), do: {:ok, [], []}
  defp textile_top(parser, tokens) do
    with {:ok, tree, r_tokens} <- well_formed_including_paragraphs(parser, tokens),
         false <- tree == [],
         {:ok, next_tree, r2_tokens} <- textile_top(parser, r_tokens)
    do
      {:ok, [tree, next_tree], r2_tokens}
    else
      _ ->
        [{_token, string} | r_tokens] = tokens
        {:ok, next_tree, r2_tokens} = textile_top(parser, r_tokens)

        {:ok, [{:text, escape_nl2br(string)}, next_tree], r2_tokens}
    end
  end


  #
  # well_formed_including_paragraphs = (markup | double_newline)*;
  #
  defp well_formed_including_paragraphs(_parser, []), do: {:ok, [], []}
  defp well_formed_including_paragraphs(parser, [{:double_newline, _nl} | r_tokens]) do
    {:ok, tree, r2_tokens} = well_formed_including_paragraphs(parser, r_tokens)

    {:ok, [{:markup, "<br/><br/>"}, tree], r2_tokens}
  end

  defp well_formed_including_paragraphs(parser, tokens) do
    with {:ok, tree, r_tokens} <- markup(parser, tokens),
         {:ok, next_tree, r2_tokens} <- well_formed_including_paragraphs(parser, r_tokens)
    do
      {:ok, [tree, next_tree], r2_tokens}
    else
      _ ->
        {:ok, [], tokens}
    end
  end

  #
  # well_formed = (markup)*;
  #
  defp well_formed(parser, tokens) do
    case markup(parser, tokens) do
      {:ok, tree, r_tokens} ->
        {:ok, next_tree, r2_tokens} = well_formed(parser, r_tokens)
        {:ok, [tree, next_tree], r2_tokens}

      _ ->
        {:ok, [], tokens}
    end
  end


  #
  # markup =
  #   blockquote | spoiler | link | image | bold | italic | strong | emphasis |
  #   code | inserted | superscript | deleted | subscript | newline | literal |
  #   bracketed_literal | text;
  #
  defp markup(parser, tokens) do
    markups = [
      &blockquote/2, &spoiler/2, &link/2, &image/2, &bold/2, &italic/2, &strong/2,
      &emphasis/2, &code/2, &inserted/2, &superscript/2, &deleted/2, &subscript/2,
      &newline/2, &literal/2, &bracketed_literal/2, &text/2
    ]

    value =
      markups
      |> Enum.find_value(fn func ->
        case func.(parser, tokens) do
          {:ok, tree, r_tokens} ->
            {:ok, tree, r_tokens}

          _ ->
            nil
        end
      end)

    value || {:error, "Expected markup"}
  end


  #
  # blockquote =
  #   blockquote_open_cite well_formed_including_paragraphs blockquote_close |
  #   blockquote_open well_formed_including_paragraphs blockquote_close;
  #
  defp blockquote(parser, [{:blockquote_open_cite, author} | r_tokens]) do
    case well_formed_including_paragraphs(parser, r_tokens) do
      {:ok, tree, [{:blockquote_close, _close} | r2_tokens]} ->
        {:ok, [{:markup, ~s|<blockquote author="#{escape_html(author)}">|}, tree, {:markup, ~s|</blockquote>|}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape_nl2br(~s|[bq="#{author}"]|)}, tree], r2_tokens}
    end
  end

  defp blockquote(parser, [{:blockquote_open, open} | r_tokens]) do
    case well_formed_including_paragraphs(parser, r_tokens) do
      {:ok, tree, [{:blockquote_close, _close} | r2_tokens]} ->
        {:ok, [{:markup, ~s|<blockquote>|}, tree, {:markup, ~s|</blockquote>|}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape_nl2br(open)}, tree], r2_tokens}
    end
  end

  defp blockquote(_parser, _tokens),
    do: {:error, "Expected a blockquote tag with optional citation"}


  #
  # spoiler =
  #   spoiler_open well_formed_including_paragraphs spoiler_close;
  #
  defp spoiler(parser, [{:spoiler_open, open} | r_tokens]) do
    case well_formed_including_paragraphs(parser, r_tokens) do
      {:ok, tree, [{:spoiler_close, _close} | r2_tokens]} ->
        {:ok, [{:markup, ~s|<span class="spoiler">|}, tree, {:markup, ~s|</span>|}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape_nl2br(open)}, tree], r2_tokens}
    end
  end

  defp spoiler(_parser, _tokens),
    do: {:error, "Expected a spoiler tag"}


  #
  # link =
  #   link_start well_formed_including_paragraphs link_end link_url;
  #
  defp link(parser, [{:link_start, start} | r_tokens]) do
    case well_formed_including_paragraphs(parser, r_tokens) do
      {:ok, tree, [{:link_end, _end}, {:link_url, url} | r2_tokens]} ->
        {:ok, [{:markup, ~s|<a href="#{escape_html(url)}">|}, tree, {:markup, ~s|</a>|}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape_nl2br(start)}, tree], r2_tokens}
    end
  end

  defp link(_parser, _tokens),
    do: {:error, "Expected a link"}


  #
  # image =
  #   image_url image_title? image_link_url?;
  #
  defp image(parser, [{:image_url, image_url}, {:image_title, title}, {:image_link_url, link_url} | r_tokens]) do
    image_url = parser.image_transform.(image_url)

    {:ok, [markup: ~s|<a href="#{escape_html(link_url)}"><img src="#{escape_html(image_url)}" title="#{escape_html(title)}"/></a>|], r_tokens}
  end

  defp image(parser, [{:image_url, image_url}, {:image_title, title} | r_tokens]) do
    image_url = parser.image_transform.(image_url)

    {:ok, [markup: ~s|<img src="#{escape_html(image_url)}" title="#{escape_html(title)}"/>|], r_tokens}
  end

  defp image(parser, [{:image_url, image_url}, {:image_link_url, link_url} | r_tokens]) do
    image_url = parser.image_transform.(image_url)

    {:ok, [markup: ~s|<a href="#{escape_html(link_url)}"><img src="#{escape_html(image_url)}"/></a>|], r_tokens}
  end

  defp image(parser, [{:image_url, image_url} | r_tokens]) do
    image_url = parser.image_transform.(image_url)

    {:ok, [markup: ~s|<img src="#{escape_html(image_url)}"/>|], r_tokens}
  end

  defp image(_parser, _tokens),
    do: {:error, "Expected an image tag"}

  #
  # bold =
  #   b_open well_formed b_close |
  #   b_b_open well_formed b_b_close;
  #
  attribute_parser(:bold, :b_open, :b_close, "<b>", "</b>")

  #
  # italic =
  #   i_open well_formed i_close |
  #   b_i_open well_formed b_i_close;
  #
  attribute_parser(:italic, :i_open, :i_close, "<i>", "</i>")

  #
  # strong =
  #   strong_open well_formed strong_close |
  #   b_strong_open well_formed b_strong_close;
  #
  attribute_parser(:strong, :strong_open, :strong_close, "<strong>", "</strong>")

  #
  # emphasis =
  #   em_open well_formed em_close |
  #   b_em_open well_formed b_em_close;
  #
  attribute_parser(:emphasis, :em_open, :em_close, "<em>", "</em>")

  #
  # code =
  #   code_open well_formed code_close |
  #   b_code_open well_formed b_code_close;
  #
  attribute_parser(:code, :code_open, :code_close, "<code>", "</code>")
 
  #
  # inserted =
  #   ins_open well_formed ins_close |
  #   b_ins_open well_formed b_ins_close;
  #
  attribute_parser(:inserted, :ins_open, :ins_close, "<ins>", "</ins>")

  #
  # superscript =
  #   sup_open well_formed sup_close |
  #   b_sup_open well_formed b_sup_close;
  #
  attribute_parser(:superscript, :sup_open, :sup_close, "<sup>", "</sup>")

  #
  # deleted =
  #   del_open well_formed del_close |
  #   b_del_open well_formed b_del_close;
  #
  attribute_parser(:deleted, :del_open, :del_close, "<del>", "</del>")

  # 
  # subscript =
  #   sub_open well_formed sub_close |
  #   b_sub_open well_formed b_sub_close;
  #
  attribute_parser(:subscript, :sub_open, :sub_close, "<sub>", "</sub>")


  #
  # Terminals
  #

  defp literal(_parser, [{:literal, text} | r_tokens]),
    do: {:ok, [markup: escape_nl2br(text)], r_tokens}

  defp literal(_parser, _tokens),
    do: {:error, "Expected a literal"}


  defp newline(_parser, [{:newline, _nl} | r_tokens]),
    do: {:ok, [markup: "<br/>"], r_tokens}

  defp newline(_parser, _tokens),
    do: {:error, "Expected a line break"}


  defp bracketed_literal(_parser, [{:bracketed_literal, text} | r_tokens]),
    do: {:ok, [markup: escape_nl2br(text)], r_tokens}

  defp bracketed_literal(_parser, _tokens),
    do: {:error, "Expected a bracketed literal"}


  defp text(_parser, [{:text, text} | r_tokens]),
    do: {:ok, [text: escape_nl2br(text)], r_tokens}

  defp text(_parser, _tokens),
    do: {:error, "Expected text"}
end