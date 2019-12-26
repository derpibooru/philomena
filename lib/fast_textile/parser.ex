defmodule FastTextile.Parser do
  @moduledoc """
  Textile parser.

  # Block rules


  bracketed_literal = bracketed_literal(tok);
  literal = literal(tok)

  bq_cite =
    bq_cite_start (literal newline double_newline char)* bq_cite_open block_markup bq_close;

  bq =
    bq_open block_markup bq_close;

  spoiler =
    spoiler_open block_markup spoiler_close;

  bracketed_link =
    bracketed_link_open block_markup unwrap(bracketed_link_url);

  bracketed_image_with_link =
    bracketed_image(tok) unwrap(unbracketed_url);

  bracketed_image =
    bracketed_image(tok);


  # Bracketed markup rules


  bracketed_bold = bracketed_b_open block_markup bracketed_b_close;
  bracketed_italic = bracketed_i_open block_markup bracketed_i_close;
  bracketed_strong = bracketed_strong_open block_markup bracketed_strong_close;
  bracketed_em = bracketed_em_open block_markup bracketed_em_close;
  bracketed_code = bracketed_code_open block_markup bracketed_code_close;
  bracketed_ins = bracketed_ins_open block_markup bracketed_ins_close;
  bracketed_sup = bracketed_sup_open block_markup bracketed_sup_close;
  bracketed_del = bracketed_del_open block_markup bracketed_del_close;
  bracketed_sub = bracketed_sub_open block_markup bracketed_sub_close;


  # Unbracketed markup rules


  unbracketed_image_with_link =
    unbracketed_image(tok) unbracketed_url;

  unbracketed_image =
    unbracketed_image(tok);


  # N.B.: the following rules use a special construction that is not really
  # representable in any BNF I'm aware of, but it simply holds the current
  # context and prevents rules from recursing into themselves.


  link =
    unbracketed_link_delim block_markup unbracketed_link_delim unbracketed_url;

  bold = b_delim inline_markup b_delim;
  italic = i_delim inline_markup i_delim;
  strong = strong_delim inline_markup strong_delim;
  em = em_delim inline_markup em_delim;
  code = code_delim inline_markup code_delim;
  ins = ins_delim inline_markup ins_delim;
  sup = sup_delim inline_markup sup_delim;
  del = del_delim inline_markup del_delim;
  sub = sub_delim inline_markup sub_delim;


  newline = newline(tok);


  # Top level
  inline_markup =
    (bracketed_literal | literal | bq_cite | bq | spoiler | bracketed_link |
    bracketed_image_with_link | bracketed_image | bracketed_bold |
    bracketed_italic | bracketed_strong | bracketed_em | bracketed_code |
    bracketed_ins | bracketed_sup | bracketed_del | bracketed_sub |
    unbracketed_image_with_link | unbracketed_image | link | bold | italic |
    strong | em | code | ins | sup | del | sub | newline | char)*;

  block_markup =
    (inline_markup double_newline)*;
  """

  alias FastTextile.Lexer
  alias Phoenix.HTML

  def parse(parser, input) do
    with {:ok, tokens, _1, _2, _3, _4} <- Lexer.lex(input),
         {:ok, tree, []} <- textile_top(parser, tokens)
    do
      partial_flatten(tree)
    else
      _ ->
        []
    end
  end

  defp textile_top(_parser, []), do: {:ok, [], []}
  defp textile_top(parser, tokens) do
    with {:ok, tree, r_tokens} <- block_markup(parser, tokens, %{}),
         false <- tree == [],
         {:ok, next_tree, r2_tokens} <- textile_top(parser, r_tokens)
    do
      {:ok, [tree, next_tree], r2_tokens}
    else
      _ ->
        [{_token, string} | r_tokens] = tokens
        {:ok, next_tree, r2_tokens} = textile_top(parser, r_tokens)

        {:ok, [{:text, escape(string)}, next_tree], r2_tokens}
    end
  end

  defp block_markup(parser, tokens, state) do
    case block_markup_element(parser, tokens, state) do
      {:ok, tree, r_tokens} when tree != [] ->
        {:ok, next_tree, r2_tokens} = block_markup(parser, r_tokens, state)

        {:ok, [tree, next_tree], r2_tokens}

      _ ->
        {:ok, [], tokens}
    end
  end

  defp block_markup_element(_parser, [{:double_newline, _} | r_tokens], _state), do: {:ok, [{:markup, "<br/><br/>"}], r_tokens}
  defp block_markup_element(parser, tokens, state), do: inline_markup(parser, tokens, state)

  defp inline_markup(parser, tokens, state) do
    case inline_markup_element(parser, tokens, state) do
      {:ok, tree, r_tokens} ->
        {:ok, next_tree, r2_tokens} = inline_markup(parser, r_tokens, state)

        {:ok, [tree, next_tree], r2_tokens}

      _ ->
        {:ok, [], tokens}
    end
  end

  defp inline_markup_element(parser, tokens, state) do
    markups = [
      &literal/3, &blockquote_cite/3, &blockquote/3, &spoiler/3,
      &bracketed_link/3, &bracketed_image_with_link/3, &bracketed_image/3,
      &bracketed_bold/3, &bracketed_italic/3, &bracketed_strong/3,
      &bracketed_em/3, &bracketed_code/3, &bracketed_ins/3, &bracketed_sup/3,
      &bracketed_del/3, &bracketed_sub/3, &unbracketed_image_with_link/3,
      &unbracketed_image/3, &link/3, &bold/3, &italic/3, &strong/3, &em/3,
      &code/3, &ins/3, &sup/3, &del/3, &sub/3, &newline/3, &char/3, &space/3
    ]

    value =
      markups
      |> Enum.find_value(fn func ->
        case func.(parser, tokens, state) do
          {:ok, tree, r_tokens} ->
            {:ok, tree, r_tokens}

          _ ->
            nil
        end
      end)

    value || {:error, "Expected inline markup"}
  end

  defp blockquote_cite_text(tokens) do
    case blockquote_cite_element(tokens) do
      {:ok, tree, r_tokens} ->
        {:ok, next_tree, r2_tokens} = blockquote_cite_text(r_tokens)

        {:ok, [tree, next_tree], r2_tokens}

      _ ->
        {:ok, [], tokens}
    end
  end

  # Text is not escaped here because it will be escaped when it is read into
  # the author attribute of the <blockquote>.
  defp blockquote_cite_element([{:literal, lit} | r_tokens]), do: {:ok, [{:text, lit}], r_tokens}
  defp blockquote_cite_element([tok | r_tokens]) when is_integer(tok) do
    {rest, r2_tokens} = extract_string(r_tokens, "")

    {:ok, [{:text, <<tok::utf8>> <> rest}], r2_tokens}
  end
  defp blockquote_cite_element(_tokens), do: {:error, "Expected a blockquote cite token"}

  defp literal(_parser, [{:literal, literal} | r_tokens], _state), do: {:ok, [{:markup, "<span class=\"literal\">"}, {:markup, escape(literal)}, {:markup, "</span>"}], r_tokens}
  defp literal(_parser, _tokens, _state), do: {:error, "Expected a bracketed literal"}

  defp blockquote_cite(parser, [{:bq_cite_start, start} | r_tokens], state) do
    case blockquote_cite_text(r_tokens) do
      {:ok, tree, [{:bq_cite_open, open} | r2_tokens]} ->
        case block_markup(parser, r2_tokens, state) do
          {:ok, tree2, [{:bq_close, _} | r3_tokens]} ->
            cite = escape(flatten(tree))

            {:ok, [{:markup, "<blockquote author=\""}, {:markup, cite}, {:markup, "\">"}, tree2, {:markup, "</blockquote>"}], r3_tokens}

          {:ok, tree2, r3_tokens} ->
            {:ok, [{:markup, escape(start)}, tree, {:markup, escape(open)}, tree2], r3_tokens}
        end

      {:ok, tree, r2_tokens} ->
        {:ok, [{:markup, escape(start)}, tree], r2_tokens}
    end
  end
  defp blockquote_cite(_parser, _tokens, _state), do: {:error, "Expected a blockquote with cite"}

  defp blockquote(parser, tokens, state), do: simple_bracketed_attr(:bq_open, :bq_close, "<blockquote>", "</blockquote>", &block_markup/3, parser, tokens, state)
  defp spoiler(parser, tokens, state), do: simple_bracketed_attr(:spoiler_open, :spoiler_close, "<span class=\"spoiler\">", "</span>", &block_markup/3, parser, tokens, state)

  defp bracketed_link(parser, [{:bracketed_link_open, blopen} | r_tokens], state) do
    case block_markup(parser, r_tokens, state) do
      {:ok, tree, [{:bracketed_link_url, link_url} | r2_tokens]} ->
        href = escape(unwrap_bracketed(link_url))

        {:ok, [{:markup, "<a href=\""}, {:markup, href}, {:markup, "\">"}, tree, {:markup, "</a>"}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:markup, escape(blopen)}, tree], r2_tokens}
    end
  end
  defp bracketed_link(_parser, _tokens, _state), do: {:error, "Expected a bracketed link"}

  defp bracketed_image_with_link(parser, [{:bracketed_image, img}, {:unbracketed_url, link_url} | r_tokens], _state) do
    href = escape(unwrap_bracketed(link_url))
    src = escape(parser.image_transform.(img))

    {:ok, [{:markup, "<span class=\"imgspoiler\"><a href=\""}, {:markup, href}, {:markup, "\"><img src=\""}, {:markup, src}, {:markup, "\"/></a></span>"}], r_tokens}
  end
  defp bracketed_image_with_link(_parser, _tokens, _state), do: {:error, "Expected an bracketed image with link"}

  defp bracketed_image(parser, [{:bracketed_image, img} | r_tokens], _state) do
    src = escape(parser.image_transform.(img))

    {:ok, [{:markup, "<span class=\"imagespoiler\"><img src=\""}, {:markup, src}, {:markup, "\"/></span>"}], r_tokens}
  end
  defp bracketed_image(_parser, _tokens, _state), do: {:error, "Expected a bracketed image"}

  defp bracketed_bold(parser, tokens, state), do: simple_bracketed_attr(:bracketed_b_open, :bracketed_b_close, "<b>", "</b>", &block_markup/3, parser, tokens, state)
  defp bracketed_italic(parser, tokens, state), do: simple_bracketed_attr(:bracketed_i_open, :bracketed_i_close, "<i>", "</i>", &block_markup/3, parser, tokens, state)
  defp bracketed_strong(parser, tokens, state), do: simple_bracketed_attr(:bracketed_strong_open, :bracketed_strong_close, "<strong>", "</strong>", &block_markup/3, parser, tokens, state)
  defp bracketed_em(parser, tokens, state), do: simple_bracketed_attr(:bracketed_em_open, :bracketed_em_close, "<em>", "</em>", &block_markup/3, parser, tokens, state)
  defp bracketed_code(parser, tokens, state), do: simple_bracketed_attr(:bracketed_code_open, :bracketed_code_close, "<code>", "</code>", &block_markup/3, parser, tokens, state)
  defp bracketed_ins(parser, tokens, state), do: simple_bracketed_attr(:bracketed_ins_open, :bracketed_ins_close, "<ins>", "</ins>", &block_markup/3, parser, tokens, state)
  defp bracketed_sup(parser, tokens, state), do: simple_bracketed_attr(:bracketed_sup_open, :bracketed_sup_close, "<sup>", "</sup>", &block_markup/3, parser, tokens, state)
  defp bracketed_del(parser, tokens, state), do: simple_bracketed_attr(:bracketed_del_open, :bracketed_del_close, "<del>", "</del>", &block_markup/3, parser, tokens, state)
  defp bracketed_sub(parser, tokens, state), do: simple_bracketed_attr(:bracketed_sub_open, :bracketed_sub_close, "<sub>", "</sub>", &block_markup/3, parser, tokens, state)

  defp unbracketed_image_with_link(parser, [{:unbracketed_image, img}, {:unbracketed_image_url, link_url} | r_tokens], _state) do
    href = escape(unwrap_unbracketed(link_url))
    src = escape(parser.image_transform.(img))

    {:ok, [{:markup, "<span class=\"imgspoiler\"><a href=\""}, {:markup, href}, {:markup, "\"><img src=\""}, {:markup, src}, {:markup, "\"/></a></span>"}], r_tokens}
  end
  defp unbracketed_image_with_link(_parser, _tokens, _state),
    do: {:error, "Expected an unbracketed image with link"}

  defp unbracketed_image(parser, [{:unbracketed_image, img} | r_tokens], _state) do
    src = escape(parser.image_transform.(img))

    {:ok, [{:markup, "<span class=\"imagespoiler\"><img src=\""}, {:markup, src}, {:markup, "\"/></span>"}], r_tokens}
  end
  defp unbracketed_image(_parser, _tokens, _state),
    do: {:error, "Expected an unbracketed image"}

  defp link(parser, [{:unbracketed_link_delim, delim} | r_tokens], state) do
    case state do
      %{link: _value} ->
        # Done, error out
        {:error, "End of rule"}

      _ ->
        case block_markup(parser, r_tokens, Map.put(state, :link, true)) do
          {:ok, tree, [{:unbracketed_link_url, url} | r2_tokens]} ->
            href = escape(unwrap_unbracketed(url))

            {:ok, [{:markup, "<a href=\""}, {:markup, href}, {:markup, "\">"}, tree, {:markup, "</a>"}], r2_tokens}

          {:ok, tree, r2_tokens} ->
            {:ok, [{:unbracketed_link_delim, delim}, tree], r2_tokens}
        end
    end
  end
  defp link(_parser, _tokens, _state), do: {:error, "Expected a link"}

  defp bold(parser, tokens, state), do: simple_unbracketed_attr(:bold, :unbracketed_b_delim, "<b>", "</b>", &inline_markup/3, parser, tokens, state)
  defp italic(parser, tokens, state), do: simple_unbracketed_attr(:italic, :unbracketed_i_delim, "<i>", "</i>", &inline_markup/3, parser, tokens, state)
  defp strong(parser, tokens, state), do: simple_unbracketed_attr(:strong, :unbracketed_strong_delim, "<strong>", "</strong>", &inline_markup/3, parser, tokens, state)
  defp em(parser, tokens, state), do: simple_unbracketed_attr(:em, :unbracketed_em_delim, "<em>", "</em>", &inline_markup/3, parser, tokens, state)
  defp code(parser, tokens, state), do: simple_unbracketed_attr(:code, :unbracketed_code_delim, "<code>", "</code>", &inline_markup/3, parser, tokens, state)
  defp ins(parser, tokens, state), do: simple_unbracketed_attr(:ins, :unbracketed_ins_delim, "<ins>", "</ins>", &inline_markup/3, parser, tokens, state)
  defp sup(parser, tokens, state), do: simple_unbracketed_attr(:sup, :unbracketed_sup_delim, "<sup>", "</sup>", &inline_markup/3, parser, tokens, state)
  defp del(parser, tokens, state), do: simple_unbracketed_attr(:del, :unbracketed_del_delim, "<del>", "</del>", &inline_markup/3, parser, tokens, state)
  defp sub(parser, tokens, state), do: simple_unbracketed_attr(:sub, :unbracketed_sub_delim, "<sub>", "</sub>", &inline_markup/3, parser, tokens, state)

  defp newline(_parser, [{:newline, _tok} | r_tokens], _state), do: {:ok, [{:markup, "<br/>"}], r_tokens}
  defp newline(_parser, _tokens, _state), do: {:error, "Expected a newline"}

  defp space(_parser, [{:space, _} | r_tokens], _state), do: {:ok, [{:text, " "}], r_tokens}
  defp space(_parser, _tokens, _state), do: {:error, "Expected whitespace"}

  # Various substitutions
  defp char(_parser, '->' ++ r_tokens, _state), do: {:ok, [{:markup, "&rarr;"}], r_tokens}
  defp char(_parser, '--' ++ r_tokens, _state), do: {:ok, [{:markup, "&mdash;"}], r_tokens}
  defp char(_parser, '...' ++ r_tokens, _state), do: {:ok, [{:markup, "&hellip;"}], r_tokens}
  defp char(_parser, '(tm)' ++ r_tokens, _state), do: {:ok, [{:markup, "&tm;"}], r_tokens}
  defp char(_parser, '(c)' ++ r_tokens, _state), do: {:ok, [{:markup, "&copy;"}], r_tokens}
  defp char(_parser, '(r)' ++ r_tokens, _state), do: {:ok, [{:markup, "&reg;"}], r_tokens}
  defp char(_parser, '\'' ++ r_tokens, _state), do: {:ok, [{:markup, "&rsquo;"}], r_tokens}
  defp char(_parser, [tok | r_tokens], _state) when is_integer(tok) do
    {rest, r2_tokens} = extract_string(r_tokens, "")

    {:ok, [{:text, escape(<<tok::utf8>> <> rest)}], r2_tokens}
  end
  defp char(_parser, _tokens, _state), do: {:error, "Expected a char"}

  defp extract_string([top | r_tokens], acc) when is_integer(top), do: extract_string(r_tokens, acc <> <<top::utf8>>)
  defp extract_string(tokens, acc), do: {acc, tokens}

  defp unwrap_unbracketed(<<"\":", rest::binary>>), do: rest
  defp unwrap_unbracketed(<<"!:", rest::binary>>), do: rest
  defp unwrap_bracketed(<<"\":", rest::binary>>), do: rest
  defp unwrap_bracketed(<<":", rest::binary>>), do: binary_part(rest, 0, byte_size(rest) - 1)

  defp simple_bracketed_attr(open_token, close_token, open_attr, close_attr, callback, parser, [{open_token, token_str} | r_tokens], state) do
    case callback.(parser, r_tokens, state) do
      {:ok, tree, [{^close_token, _} | r2_tokens]} ->
        {:ok, [{:markup, open_attr}, tree, {:markup, close_attr}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, token_str}, tree], r2_tokens}
    end
  end
  defp simple_bracketed_attr(_open_token, _close_token, _open_attr, _close_attr, _callback, _parser, _tokens, _state),
    do: {:error, "Expected a simple bracketed attribute"}

  defp simple_unbracketed_attr(this_state, delim_token, open_attr, close_attr, callback, parser, [{delim_token, token_str} | r_tokens], state) do
    case state do
      %{^this_state => _value} ->
        # Exit state: No other rule will match so we can just error out here
        {:error, "End of rule"}

      _ ->
        # Enter state
        case callback.(parser, r_tokens, Map.put(state, this_state, true)) do
          {:ok, tree, [{^delim_token, _} | r2_tokens]} ->
            {:ok, [{:markup, open_attr}, tree, {:markup, close_attr}], r2_tokens}

          {:ok, tree, r2_tokens} ->
            {:ok, [{:text, token_str}, tree], r2_tokens}
        end
    end
  end
  defp simple_unbracketed_attr(_this_state, _delim_token, _open_attr, _close_attr, _callback, _parser, _tokens, _state),
    do: {:error, "Expected a simple unbracketed attribute"}

  defp escape(text), do: HTML.html_escape(text) |> HTML.safe_to_string()
  defp flatten(tree) do
    tree
    |> List.flatten()
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.join()
  end

  defp partial_flatten(tree) do
    List.flatten(tree)
  end
end
