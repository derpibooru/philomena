# LUNA PRESENTS THEE
#
# DA ULTIMATE, BESTEST, MOST SECURE AND DEFINITELY NOT BUGGY
# TEXTILE TO MARKDOWN CONVERTER PARSER LIBRARY THING!!!!!
#
# IT'S SO AWESOME I HAVE TO DESCRIBE IT IN ALL CAPS
#
# BY LOOKING AT THIS SOURCE CODE YOU AGREE THAT I MAY NOT BE HELD
# RESPONSIBLE FOR YOU DEVELOPING EYE CANCER
#
# YOU'VE BEEN WARNED
#
# COPYRIGHT (C) (R) (TM) LUNA (C) (R) (TM) 2021-206969696969
defmodule Philomena.Textile.ParserMarkdown do
  alias Philomena.Textile.Lexer
  alias Philomena.Markdown

  def parse(parser, input) do
    parser = Map.put(parser, :state, %{})

    with {:ok, tokens, _1, _2, _3, _4} <- Lexer.lex(String.trim(input || "")),
         {:ok, tree, [], _level} <- repeat(&textile/3, parser, tokens, 0) do
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

  def flatten_unquote(tree) do
    tree
    |> List.flatten()
    |> Enum.map_join("", fn {_k, v} ->
      Regex.replace(~r/\n(> )/, v, "\n")
    end)
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
  defp repeat(rule, parser, tokens, level) do
    case rule.(parser, tokens, level) do
      {:ok, tree, r_tokens} ->
        {:ok, tree2, r2_tokens, level} = repeat(rule, parser, r_tokens, level)
        {:ok, [tree, tree2], r2_tokens, level}

      _ ->
        {:ok, [], tokens, level}
    end
  end

  # Helper to match a simple recursive grammar rule of the following form:
  #
  #   open_token callback* close_token
  #
  defp simple_recursive(
         open_token,
         close_token,
         open_tag,
         close_tag,
         callback,
         parser,
         [
           {open_token, open} | r_tokens
         ],
         level
       ) do
    case repeat(callback, parser, r_tokens, level) do
      {:ok, tree, [{^close_token, _} | r2_tokens], _level} ->
        {:ok, [{:markup, open_tag}, tree, {:markup, close_tag}], r2_tokens}

      {:ok, tree, r2_tokens, _level} ->
        {:ok, [{:text, open}, tree], r2_tokens}
    end
  end

  defp simple_recursive(
         _open_token,
         _close_token,
         _open_tag,
         _close_tag,
         _callback,
         _parser,
         _tokens,
         _level
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
         [{open_token, open} | r_tokens],
         level
       ) do
    case parser.state do
      %{^state => _} ->
        {:error, "End of rule"}

      _ ->
        case r_tokens do
          [{forbidden_lookahead, _la} | _] when forbidden_lookahead in [:space, :newline] ->
            {:ok, [{:text, open}], r_tokens}

          _ ->
            case repeat(callback, put_state(parser, state), r_tokens, level) do
              {:ok, tree, [{^close_token, close}, {^lookahead_not, ln} | r2_tokens], _level} ->
                {:ok, [{:text, open}, tree, {:text, close}], [{lookahead_not, ln} | r2_tokens]}

              {:ok, tree, [{^close_token, _} | r2_tokens], _level} ->
                {:ok, [{:markup, open_tag}, tree, {:markup, close_tag}], r2_tokens}

              {:ok, tree, r2_tokens, _level} ->
                {:ok, [{:text, open}, tree], r2_tokens}
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
         _tokens,
         _level
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

  defp inline_textile_element(parser, tokens, level) do
    [
      {:b_delim, :b, "**", "**"},
      {:i_delim, :i, "_", "_"},
      {:strong_delim, :strong, "**", "**"},
      {:em_delim, :em, "*", "*"},
      {:ins_delim, :ins, "__", "__"},
      {:sup_delim, :sup, "^", "^"},
      {:del_delim, :del, "~~", "~~"},
      {:sub_delim, :sub, "%", "%"}
    ]
    |> Enum.find_value(fn {delim_token, state, open_tag, close_tag} ->
      simple_lookahead_not(
        delim_token,
        delim_token,
        open_tag,
        close_tag,
        :quicktxt,
        &inline_textile_element/3,
        state,
        parser,
        tokens,
        level
      )
      |> case do
        {:ok, tree, r_tokens} ->
          {:ok, tree, r_tokens}

        _ ->
          nil
      end
    end)
    |> case do
      nil -> inner_inline_textile_element(parser, tokens, level)
      value -> value
    end
  end

  defp inner_inline_textile_element(parser, [{token, t}, {:quicktxt, q} | r_tokens], level)
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
    case inline_textile_element(parser, [{:quicktxt, q} | r_tokens], level) do
      {:ok, tree, r2_tokens} ->
        {:ok, [{:text, t}, tree], r2_tokens}

      _ ->
        {:ok, [{:text, t}], [{:quicktxt, q} | r_tokens]}
    end
  end

  defp inner_inline_textile_element(parser, [{:link_delim, open} | r_tokens], level) do
    case repeat(&block_textile_element/3, parser, r_tokens, level) do
      {:ok, tree, [{:unbracketed_link_url, <<"\":", url::binary>>} | r2_tokens], _level} ->
        href = url

        {:ok, [{:markup, "["}, tree, {:markup, "]("}, {:markup, href}, {:markup, ")"}], r2_tokens}

      {:ok, tree, r2_tokens, _level} ->
        {:ok, [{:text, open}, tree], r2_tokens}
    end
  end

  defp inner_inline_textile_element(parser, [{:bracketed_link_open, open} | r_tokens], level) do
    case repeat(&inline_textile_element/3, parser, r_tokens, level) do
      {:ok, tree, [{:bracketed_link_url, <<"\":", url::binary>>} | r2_tokens], _level} ->
        href = url

        {:ok, [{:markup, "["}, tree, {:markup, "]("}, {:markup, href}, {:markup, ")"}], r2_tokens}

      {:ok, tree, r2_tokens, _level} ->
        {:ok, [{:text, open}, tree], r2_tokens}
    end
  end

  defp inner_inline_textile_element(
         parser,
         [
           {token, img},
           {:unbracketed_image_url, <<":", url::binary>>} | r_tokens
         ],
         _level
       )
       when token in [:unbracketed_image, :bracketed_image] do
    img = parser.image_transform.(img)

    {:ok,
     [
       {:markup, "[![full]("},
       {:markup, img},
       {:markup, ")]("},
       {:markup, url},
       {:markup, ")"}
     ], r_tokens}
  end

  defp inner_inline_textile_element(parser, [{token, img} | r_tokens], _level)
       when token in [:unbracketed_image, :bracketed_image] do
    img = parser.image_transform.(img)

    {:ok,
     [
       {:markup, "![full]("},
       {:markup, img},
       {:markup, ")"}
     ], r_tokens}
  end

  defp inner_inline_textile_element(parser, [{:code_delim, open} | r_tokens], level) do
    case parser.state do
      %{code: _} ->
        {:error, "End of rule"}

      _ ->
        case repeat(&inline_textile_element/3, put_state(parser, :code), r_tokens, level) do
          {:ok, tree, [{:code_delim, _} | r2_tokens], _level} ->
            {:ok, [{:markup, "`"}, tree, {:markup, "`"}], r2_tokens}

          {:ok, tree, r2_tokens, _level} ->
            {:ok, [{:text, open}, tree], r2_tokens}
        end
    end
  end

  defp inner_inline_textile_element(parser, tokens, level) do
    inline_textile_element_not_opening_markup(parser, tokens, level)
  end

  #
  # bq_cite_text = (?!bq_cite_open);
  #

  # Note that text is not escaped here because it will be escaped
  # when the tree is flattened
  defp bq_cite_text(_parser, [{:bq_cite_open, _open} | _rest], _level) do
    {:error, "Expected cite tokens"}
  end

  defp bq_cite_text(_parser, [{:char, lit} | r_tokens], _level) do
    {:ok, [{:text, <<lit::utf8>>}], r_tokens}
  end

  defp bq_cite_text(_parser, [{:quicktxt, lit} | r_tokens], _level) do
    {:ok, [{:text, <<lit::utf8>>}], r_tokens}
  end

  defp bq_cite_text(_parser, [{:space, _} | r_tokens], _level) do
    {:ok, [{:text, " "}], r_tokens}
  end

  defp bq_cite_text(_parser, [{_token, t} | r_tokens], _level) do
    {:ok, [{:text, t}], r_tokens}
  end

  defp bq_cite_text(_parser, _tokens, _level) do
    {:error, "Expected cite tokens"}
  end

  #
  #  inline_textile_element_not_opening_markup =
  #    literal | space | char |
  #    quicktxt opening_markup quicktxt |
  #    quicktxt |
  #    opening_block_tag block_textile_element* closing_block_tag;
  #

  defp inline_textile_element_not_opening_markup(_parser, [{:literal, lit} | r_tokens], _level) do
    {:ok, [{:markup, Markdown.escape_markdown(lit)}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:space, _} | r_tokens], _level) do
    {:ok, [{:text, " "}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:char, lit} | r_tokens], _level) do
    {binary, r2_tokens} = assemble_binary(:char, <<lit::utf8>>, r_tokens)
    {:ok, [{:text, binary}], r2_tokens}
  end

  defp inline_textile_element_not_opening_markup(
         _parser,
         [
           {:quicktxt, q1},
           {token, t},
           {:quicktxt, q2} | r_tokens
         ],
         _level
       )
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
    {:ok, [{:text, <<q1::utf8>>}, {:text, t}, {:text, <<q2::utf8>>}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(_parser, [{:quicktxt, lit} | r_tokens], _level) do
    {:ok, [{:text, <<lit::utf8>>}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(
         parser,
         [{:bq_cite_start, start} | r_tokens],
         level
       ) do
    case repeat(&bq_cite_text/3, parser, r_tokens, level) do
      {:ok, tree, [{:bq_cite_open, open} | r2_tokens], _level} ->
        case repeat(&block_textile_element/3, parser, r2_tokens, level + 1) do
          {:ok, tree2, [{:bq_close, _} | r3_tokens], level} ->
            {:ok,
             [
               {:markup, "\n" <> String.duplicate("> ", level)},
               tree2,
               {:markup, "\n" <> String.duplicate("> ", level - 1)}
             ], r3_tokens}

          {:ok, tree2, r3_tokens, _level} ->
            {:ok,
             [
               {:text, start},
               {:text, flatten(tree)},
               {:text, open},
               tree2
             ], r3_tokens}
        end

      _ ->
        {:ok, [{:text, start}], r_tokens}
    end
  end

  defp inline_textile_element_not_opening_markup(
         _parser,
         [{:bq_cite_open, tok} | r_tokens],
         _level
       ) do
    {:ok, [{:text, tok}], r_tokens}
  end

  defp inline_textile_element_not_opening_markup(
         parser,
         [{:bq_open, start} | r_tokens],
         level
       ) do
    case repeat(&block_textile_element/3, parser, r_tokens, level + 1) do
      {:ok, tree, [{:bq_close, _} | r2_tokens], level} ->
        {:ok,
         [
           {:markup, "\n" <> String.duplicate("> ", level)},
           tree,
           {:markup, "\n" <> String.duplicate("> ", level - 1)}
         ], r2_tokens}

      {:ok, tree, r2_tokens, _level} ->
        {:ok,
         [
           {:text, start},
           {:text, flatten_unquote(tree)}
         ], r2_tokens}
    end
  end

  defp inline_textile_element_not_opening_markup(parser, tokens, level) do
    [
      {:spoiler_open, :spoiler_close, "||", "||"},
      {:bracketed_b_open, :bracketed_b_close, "**", "**"},
      {:bracketed_i_open, :bracketed_i_close, "_", "_"},
      {:bracketed_strong_open, :bracketed_strong_close, "**", "**"},
      {:bracketed_em_open, :bracketed_em_close, "*", "*"},
      {:bracketed_code_open, :bracketed_code_close, "```", "```"},
      {:bracketed_ins_open, :bracketed_ins_close, "__", "__"},
      {:bracketed_sup_open, :bracketed_sup_close, "^", "^"},
      {:bracketed_del_open, :bracketed_del_close, "~~", "~~"},
      {:bracketed_sub_open, :bracketed_sub_close, "%", "%"}
    ]
    |> Enum.find_value(fn {open_token, close_token, open_tag, close_tag} ->
      simple_recursive(
        open_token,
        close_token,
        open_tag,
        close_tag,
        &block_textile_element/3,
        parser,
        tokens,
        level
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

  defp block_textile_element(_parser, [{:double_newline, _} | r_tokens], level)
       when level > 0 do
    one = "\n" <> String.duplicate("> ", level)
    {:ok, [{:markup, String.duplicate(one, 2)}], r_tokens}
  end

  defp block_textile_element(_parser, [{:newline, _} | r_tokens], level) when level > 0 do
    {:ok, [{:markup, "\n" <> String.duplicate("> ", level)}], r_tokens}
  end

  # &nbsp;
  defp block_textile_element(_parser, [{:double_newline, _} | r_tokens], level)
       when level == 0 do
    {:ok, [{:markup, "\n\u00a0\n"}], r_tokens}
  end

  defp block_textile_element(_parser, [{:newline, _} | r_tokens], level) when level == 0 do
    {:ok, [{:markup, "\u00a0\n"}], r_tokens}
  end

  defp block_textile_element(parser, tokens, level) do
    inline_textile_element(parser, tokens, level)
  end

  #
  #  textile =
  #    (block_textile_element | TOKEN)* eos;
  #

  defp textile(parser, tokens, level) do
    case block_textile_element(parser, tokens, level) do
      {:ok, tree, r_tokens} ->
        {:ok, tree, r_tokens}

      _ ->
        case tokens do
          [{_, string} | r_tokens] ->
            {:ok, [{:text, string}], r_tokens}

          _ ->
            {:error, "Expected textile"}
        end
    end
  end
end
