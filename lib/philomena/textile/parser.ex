defmodule Philomena.Textile.Parser do
  alias Philomena.Textile.Lexer
  alias Phoenix.HTML

  def parse(parser, input) do
    parser = Map.put(parser, :state, %{})

    with {:ok, tokens, _1, _2, _3, _4} <- Lexer.lex(String.trim(input || "")),
         {:ok, tree, []} <- repeat(&textile/2, parser, tokens) do
      partial_flatten(tree)
    else
      _ ->
        []
    end
  end

  # Helper to turn a parse tree into a string
  def flatten(tree) do
    tree
    |> List.flatten()
    |> Enum.map_join("", fn {_k, v} -> v end)
  end

  # Helper to escape HTML
  defp escape(text) do
    text
    |> HTML.html_escape()
    |> HTML.safe_to_string()
  end

  # Helper to turn a parse tree into a list
  def partial_flatten(tree) do
    tree
    |> List.flatten()
    |> Enum.chunk_by(fn {k, _v} -> k end)
    |> Enum.map(fn list ->
      [{type, _v} | _rest] = list

      value = Enum.map_join(list, "", fn {_k, v} -> v end)

      {type, value}
    end)
  end

  defp put_state(parser, new_state) do
    state = Map.put(parser.state, new_state, true)
    Map.put(parser, :state, state)
  end

  # Helper corresponding to Kleene star (*) operator
  # Match a specificed rule zero or more times
  defp repeat(rule, parser, tokens) do
    case rule.(parser, tokens) do
      {:ok, tree, r_tokens} ->
        {:ok, tree2, r2_tokens} = repeat(rule, parser, r_tokens)
        {:ok, [tree, tree2], r2_tokens}

      _ ->
        {:ok, [], tokens}
    end
  end

  # Helper to match a simple recursive grammar rule of the following form:
  #
  #   open_token callback* close_token
  #
  defp simple_recursive(open_token, close_token, open_tag, close_tag, callback, parser, [
         {open_token, open} | r_tokens
       ]) do
    case repeat(callback, parser, r_tokens) do
      {:ok, tree, [{^close_token, _} | r2_tokens]} ->
        {:ok, [{:markup, open_tag}, tree, {:markup, close_tag}], r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape(open)}, tree], r2_tokens}
    end
  end

  defp simple_recursive(
         _open_token,
         _close_token,
         _open_tag,
         _close_tag,
         _callback,
         _parser,
         _tokens
       ) do
    {:error, "Expected a simple recursive rule"}
  end

  # Helper to match a simple recursive grammar rule with negative lookahead:
  #
  #   open_token callback* close_token (?!lookahead_not)
  #
  defp simple_lookahead_not(
         open_token,
         close_token,
         open_tag,
         close_tag,
         lookahead_not,
         callback,
         state,
         parser,
         [{open_token, open} | r_tokens]
       ) do
    case parser.state do
      %{^state => _} ->
        {:error, "End of rule"}

      _ ->
        case r_tokens do
          [{forbidden_lookahead, _la} | _] when forbidden_lookahead in [:space, :newline] ->
            {:ok, [{:text, escape(open)}], r_tokens}

          _ ->
            case repeat(callback, put_state(parser, state), r_tokens) do
              {:ok, tree, [{^close_token, close}, {^lookahead_not, ln} | r2_tokens]} ->
                {:ok, [{:text, escape(open)}, tree, {:text, escape(close)}],
                 [{lookahead_not, ln} | r2_tokens]}

              {:ok, tree, [{^close_token, _} | r2_tokens]} ->
                {:ok, [{:markup, open_tag}, tree, {:markup, close_tag}], r2_tokens}

              {:ok, tree, r2_tokens} ->
                {:ok, [{:text, escape(open)}, tree], r2_tokens}
            end
        end
    end
  end

  defp simple_lookahead_not(
         _open_token,
         _close_token,
         _open_tag,
         _close_tag,
         _lookahead_not,
         _callback,
         _state,
         _parser,
         _tokens
       ) do
    {:error, "Expected a simple lookahead not rule"}
  end

  # Helper to efficiently assemble a UTF-8 binary from tokens of the
  # given type
  defp assemble_binary(token_type, accumulator, [{token_type, t} | stream]) do
    assemble_binary(token_type, accumulator <> <<t::utf8>>, stream)
  end

  defp assemble_binary(_token_type, accumulator, tokens), do: {accumulator, tokens}

  #
  #  inline_textile_element =
  #    opening_markup inline_textile_element* closing_markup (?!quicktxt) |
  #    closing_markup (?=quicktxt) |
  #    link_delim block_textile_element* link_url |
  #    image url? |
  #    code_delim inline_textile_element* code_delim |
  #    inline_textile_element_not_opening_markup;
  #

  defp inline_textile_element(parser, tokens) do
    [
      {:b_delim, :b, "<b>", "</b>"},
      {:i_delim, :i, "<i>", "</i>"},
      {:strong_delim, :strong, "<strong>", "</strong>"},
      {:em_delim, :em, "<em>", "</em>"},
      {:ins_delim, :ins, "<ins>", "</ins>"},
      {:sup_delim, :sup, "<sup>", "</sup>"},
      {:del_delim, :del, "<del>", "</del>"},
      {:sub_delim, :sub, "<sub>", "</sub>"}
    ]
    |> Enum.find_value(fn {delim_token, state, open_tag, close_tag} ->
      simple_lookahead_not(
        delim_token,
        delim_token,
        open_tag,
        close_tag,
        :quicktxt,
        &inline_textile_element/2,
        state,
        parser,
        tokens
      )
      |> case do
        {:ok, tree, r_tokens} ->
          {:ok, tree, r_tokens}

        _ ->
          nil
      end
    end)
    |> case do
      nil -> inner_inline_textile_element(parser, tokens)
      value -> value
    end
  end

  defp inner_inline_textile_element(parser, [{token, t}, {:quicktxt, q} | r_tokens])
       when token in [
              :b_delim,
              :i_delim,
              :strong_delim,
              :em_delim,
              :ins_delim,
              :sup_delim,
              :del_delim,
              :sub_delim
            ] do
    case inline_textile_element(parser, [{:quicktxt, q} | r_tokens]) do
      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape(t)}, tree], r2_tokens}

      _ ->
        {:ok, [{:text, escape(t)}], [{:quicktxt, q} | r_tokens]}
    end
  end

  defp inner_inline_textile_element(parser, [{:link_delim, open} | r_tokens]) do
    case repeat(&block_textile_element/2, parser, r_tokens) do
      {:ok, tree, [{:unbracketed_link_url, <<"\":", url::binary>>} | r2_tokens]} ->
        href = escape(url)

        {:ok,
         [{:markup, "<a href=\""}, {:markup, href}, {:markup, "\">"}, tree, {:markup, "</a>"}],
         r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape(open)}, tree], r2_tokens}
    end
  end

  defp inner_inline_textile_element(parser, [{:bracketed_link_open, open} | r_tokens]) do
    case repeat(&inline_textile_element/2, parser, r_tokens) do
      {:ok, tree, [{:bracketed_link_url, <<"\":", url::binary>>} | r2_tokens]} ->
        href = escape(url)

        {:ok,
         [{:markup, "<a href=\""}, {:markup, href}, {:markup, "\">"}, tree, {:markup, "</a>"}],
         r2_tokens}

      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, escape(open)}, tree], r2_tokens}
    end
  end

  defp inner_inline_textile_element(parser, [
         {token, img},
         {:unbracketed_image_url, <<":", url::binary>>} | r_tokens
       ])
       when token in [:unbracketed_image, :bracketed_image] do
    img = parser.image_transform.(img)

    {:ok,
     [
       {:markup, "<a href=\""},
       {:markup, escape(url)},
       {:markup, "\"><span class=\"imgspoiler\"><img src=\""},
       {:markup, escape(img)},
       {:markup, "\"/></span></a>"}
     ], r_tokens}
  end

  defp inner_inline_textile_element(parser, [{token, img} | r_tokens])
       when token in [:unbracketed_image, :bracketed_image] do
    img = parser.image_transform.(img)

    {:ok,
     [
       {:markup, "<span class=\"imgspoiler\"><img src=\""},
       {:markup, escape(img)},
       {:markup, "\"/></span>"}
     ], r_tokens}
  end

  defp inner_inline_textile_element(parser, [{:code_delim, open} | r_tokens]) do
    case parser.state do
      %{code: _} ->
        {:error, "End of rule"}

      _ ->
        case repeat(&inline_textile_element/2, put_state(parser, :code), r_tokens) do
          {:ok, tree, [{:code_delim, _} | r2_tokens]} ->
            {:ok, [{:markup, "<code>"}, tree, {:markup, "</code>"}], r2_tokens}

          {:ok, tree, r2_tokens} ->
            {:ok, [{:text, escape(open)}, tree], r2_tokens}
        end
    end
  end

  defp inner_inline_textile_element(parser, tokens) do
    inline_textile_element_not_opening_markup(parser, tokens)
  end

  #
  # bq_cite_text = (?!bq_cite_open);
  #

  # Note that text is not escaped here because it will be escaped
  # when the tree is flattened
  defp bq_cite_text(_parser, [{:bq_cite_open, _open} | _rest]) do
    {:error, "Expected cite tokens"}
  end

  defp bq_cite_text(_parser, [{:char, lit} | r_tokens]) do
    {:ok, [{:text, <<lit::utf8>>}], r_tokens}
  end

  defp bq_cite_text(_parser, [{:quicktxt, lit} | r_tokens]) do
    {:ok, [{:text, <<lit::utf8>>}], r_tokens}
  end

  defp bq_cite_text(_parser, [{:space, _} | r_tokens]) do
    {:ok, [{:text, " "}], r_tokens}
  end

  defp bq_cite_text(_parser, [{_token, t} | r_tokens]) do
    {:ok, [{:text, t}], r_tokens}
  end

  defp bq_cite_text(_parser, _tokens) do
    {:error, "Expected cite tokens"}
  end

  #
  #  inline_textile_element_not_opening_markup =
  #    literal | space | char |
  #    quicktxt opening_markup quicktxt |
  #    quicktxt |
  #    opening_block_tag block_textile_element* closing_block_tag;
  #

  defp inline_textile_element_not_opening_markup(_parser, [{:literal, lit} | r_tokens]) do
    {:ok, [{:markup, "<span class=\"literal\">"}, {:markup, escape(lit)}, {:markup, "</span>"}],
     r_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:space, _} | r_tokens]) do
    {:ok, [{:text, " "}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:char, lit} | r_tokens]) do
    {binary, r2_tokens} = assemble_binary(:char, <<lit::utf8>>, r_tokens)

    {:ok, [{:text, escape(binary)}], r2_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [
         {:quicktxt, q1},
         {token, t},
         {:quicktxt, q2} | r_tokens
       ])
       when token in [
              :b_delim,
              :i_delim,
              :strong_delim,
              :em_delim,
              :ins_delim,
              :sup_delim,
              :del_delim,
              :sub_delim
            ] do
    {:ok, [{:text, escape(<<q1::utf8>>)}, {:text, escape(t)}, {:text, escape(<<q2::utf8>>)}],
     r_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:quicktxt, lit} | r_tokens]) do
    {:ok, [{:text, escape(<<lit::utf8>>)}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(parser, [{:bq_cite_start, start} | r_tokens]) do
    case repeat(&bq_cite_text/2, parser, r_tokens) do
      {:ok, tree, [{:bq_cite_open, open} | r2_tokens]} ->
        case repeat(&block_textile_element/2, parser, r2_tokens) do
          {:ok, tree2, [{:bq_close, _} | r3_tokens]} ->
            cite = escape(flatten(tree))

            {:ok,
             [
               {:markup, "<blockquote author=\""},
               {:markup, cite},
               {:markup, "\">"},
               tree2,
               {:markup, "</blockquote>"}
             ], r3_tokens}

          {:ok, tree2, r3_tokens} ->
            {:ok,
             [
               {:text, escape(start)},
               {:text, escape(flatten(tree))},
               {:text, escape(open)},
               tree2
             ], r3_tokens}
        end

      _ ->
        {:ok, [{:text, escape(start)}], r_tokens}
    end
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:bq_cite_open, tok} | r_tokens]) do
    {:ok, [{:text, escape(tok)}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(parser, tokens) do
    [
      {:bq_open, :bq_close, "<blockquote>", "</blockquote>"},
      {:spoiler_open, :spoiler_close, "<span class=\"spoiler\">", "</span>"},
      {:bracketed_b_open, :bracketed_b_close, "<b>", "</b>"},
      {:bracketed_i_open, :bracketed_i_close, "<i>", "</i>"},
      {:bracketed_strong_open, :bracketed_strong_close, "<strong>", "</strong>"},
      {:bracketed_em_open, :bracketed_em_close, "<em>", "</em>"},
      {:bracketed_code_open, :bracketed_code_close, "<code>", "</code>"},
      {:bracketed_ins_open, :bracketed_ins_close, "<ins>", "</ins>"},
      {:bracketed_sup_open, :bracketed_sup_close, "<sup>", "</sup>"},
      {:bracketed_del_open, :bracketed_del_close, "<del>", "</del>"},
      {:bracketed_sub_open, :bracketed_sub_close, "<sub>", "</sub>"}
    ]
    |> Enum.find_value(fn {open_token, close_token, open_tag, close_tag} ->
      simple_recursive(
        open_token,
        close_token,
        open_tag,
        close_tag,
        &block_textile_element/2,
        parser,
        tokens
      )
      |> case do
        {:ok, tree, r_tokens} ->
          {:ok, tree, r_tokens}

        _ ->
          nil
      end
    end)
    |> Kernel.||({:error, "Expected block markup"})
  end

  #
  #  block_textile_element =
  #    double_newline | newline | inline_textile_element;
  #

  defp block_textile_element(_parser, [{:double_newline, _} | r_tokens]) do
    {:ok, [{:markup, "<br/><br/>"}], r_tokens}
  end

  defp block_textile_element(_parser, [{:newline, _} | r_tokens]) do
    {:ok, [{:markup, "<br/>"}], r_tokens}
  end

  defp block_textile_element(parser, tokens) do
    inline_textile_element(parser, tokens)
  end

  #
  #  textile =
  #    (block_textile_element | TOKEN)* eos;
  #

  defp textile(parser, tokens) do
    case block_textile_element(parser, tokens) do
      {:ok, tree, r_tokens} ->
        {:ok, tree, r_tokens}

      _ ->
        case tokens do
          [{_, string} | r_tokens] ->
            {:ok, [{:text, escape(string)}], r_tokens}

          _ ->
            {:error, "Expected textile"}
        end
    end
  end
end
