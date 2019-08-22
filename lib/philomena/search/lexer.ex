defmodule Philomena.Search.Lexer do
  def lex(input) do
    {:ok, accept(input |> to_charlist, :outer)}
  rescue
    e in ArgumentError ->
      {:error, e.message}
    _ ->
      {:error, "Parsing error."}
  end

  #
  # Outer state (not inside a term, spaces irrelevant)
  #

  defp accept([], :outer), do: [eof: "$"]
  defp accept('AND' ++ rest, :outer), do: [{:and, "AND"} | accept(rest, :outer)]
  defp accept('NOT' ++ rest, :outer), do: [{:not, "NOT"} | accept(rest, :outer)]
  defp accept('OR' ++ rest, :outer), do: [{:or, "OR"} | accept(rest, :outer)]
  defp accept('||' ++ rest, :outer), do: [{:or, "||"} | accept(rest, :outer)]
  defp accept('&&' ++ rest, :outer), do: [{:and, "&&"} | accept(rest, :outer)]
  defp accept(',' ++ rest, :outer), do: [{:and, ","} | accept(rest, :outer)]
  defp accept('!' ++ rest, :outer), do: [{:not, "!"} | accept(rest, :outer)]
  defp accept('-' ++ rest, :outer), do: [{:not, "-"} | accept(rest, :outer)]
  defp accept('(' ++ rest, :outer), do: [{:lparen, "("} | accept(rest, :outer)]
  defp accept(')' ++ rest, :outer), do: [{:rparen, ")"} | accept(rest, :outer)]
  defp accept('^' ++ rest, :outer), do: [{:boost, "^"} | accept(rest, :float)]
  defp accept('~' ++ rest, :outer), do: [{:fuzz, "~"} | accept(rest, :float)]
  defp accept(' ' ++ rest, :outer), do: accept(rest, :outer)
  defp accept('\t' ++ rest, :outer), do: accept(rest, :outer)
  defp accept('\n' ++ rest, :outer), do: accept(rest, :outer)
  defp accept('\r' ++ rest, :outer), do: accept(rest, :outer)
  defp accept('\v' ++ rest, :outer), do: accept(rest, :outer)
  defp accept('\f' ++ rest, :outer), do: accept(rest, :outer)
  defp accept('"' ++ rest, :outer), do: accept(rest, "", :quoted_term)
  defp accept(input, :outer), do: accept(input, "", 0, :term)

  #
  # Quoted term state
  #

  defp accept('\\"' ++ rest, term, :quoted_term), do: accept(rest, term <> "\"", :quoted_term)
  defp accept('\\', _term, :quoted_term), do: raise ArgumentError, "Unpaired backslash."
  defp accept('"' ++ rest, term, :quoted_term), do: [{:term, term} | accept(rest, :outer)]
  defp accept([c] ++ rest, term, :quoted_term), do: accept(rest, term <> <<c::utf8>>, :quoted_term)
  defp accept([], _term, :quoted_term), do: raise ArgumentError, "Imbalanced quotes."

  #
  # Term state
  #

  defp accept([?\\, c] ++ rest, term, depth, :term) when c in '()\\', do: accept(rest, term <> <<c::utf8>>, depth, :term)
  defp accept('\\', _term, _depth, :term), do: raise ArgumentError, "Unpaired backslash."
  defp accept('(' ++ rest, term, depth, :term), do: accept(rest, term <> "(", depth + 1, :term)
  defp accept(')' ++ rest, term, 0, :term), do: [{:term, String.trim(term)}, {:rparen, ")"} | accept(rest, :outer)]
  defp accept(')' ++ rest, term, depth, :term), do: accept(rest, term <> ")", depth - 1, :term)
  defp accept(' AND' ++ rest, term, 0, :term), do: [{:term, String.trim(term)}, {:and, "AND"} | accept(rest, :outer)]
  defp accept(' OR' ++ rest, term, 0, :term), do: [{:term, String.trim(term)}, {:or, "OR"} | accept(rest, :outer)]
  defp accept(' &&' ++ rest, term, 0, :term), do: [{:term, String.trim(term)}, {:and, "&&"} | accept(rest, :outer)]
  defp accept(' ||' ++ rest, term, 0, :term), do: [{:term, String.trim(term)}, {:or, "||"} | accept(rest, :outer)]
  defp accept(',' ++ rest, term, 0, :term), do: [{:term, String.trim(term)}, {:and, ","} | accept(rest, :outer)]
  defp accept([?^, c] ++ rest, term, 0, :term) when c in '+-0123456789', do: [{:term, term}, {:boost, "^"} | accept([c | rest], :float)]
  defp accept([?~, c] ++ rest, term, 0, :term) when c in '+-0123456789', do: [{:term, term}, {:fuzz, "~"} | accept([c | rest], :float)]
  defp accept('^' ++ rest, term, depth, :term), do: accept(rest, term <> "^", depth, :term)
  defp accept('~' ++ rest, term, depth, :term), do: accept(rest, term <> "~", depth, :term)
  defp accept([c] ++ rest, term, depth, :term), do: accept(rest, term <> <<c::utf8>>, depth, :term)
  defp accept([], term, 0, :term), do: [term: String.trim(term), eof: "$"]
  defp accept([], _term, _depth, :term), do: raise ArgumentError, "Imbalanced parentheses."

  #
  # Number state (for boosting, fuzzing)
  #

  defp accept('+' ++ rest, :float), do: accept(rest, "", :float_w)
  defp accept('-' ++ rest, :float), do: accept(rest, "-", :float_w)
  defp accept(input, :float), do: accept(input, "", :float_w)

  defp accept([c] ++ rest, term, :float_w) when c in ?0..?9, do: accept(rest, term <> <<c::utf8>>, :float_w)
  defp accept('.' ++ rest, term, :float_w), do: accept(rest, term <> ".", :float_f)
  defp accept(')' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:rparen, ")"} | accept(rest, :outer)]
  defp accept(' AND' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:rparen, ")"} | accept(rest, :outer)]
  defp accept(' OR' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:and, "AND"} | accept(rest, :outer)]
  defp accept(' &&' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:or, "||"} | accept(rest, :outer)]
  defp accept(' ||' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:and, "&&"} | accept(rest, :outer)]
  defp accept(',' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:and, ","} | accept(rest, :outer)]
  defp accept('^' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:boost, "^"} | accept(rest, :float)]
  defp accept('~' ++ rest, term, :float_w), do: [{:float, to_number(term)}, {:fuzz, "~"} | accept(rest, :float)]
  defp accept(' ' ++ rest, term, :float_w), do: [{:float, to_number(term)} | accept(rest, :outer)]
  defp accept([], term, :float_w), do: [float: to_number(term), eof: "$"]
  defp accept(_input, _term, :float_w), do: raise ArgumentError, "Expected a number."

  defp accept([c] ++ rest, term, :float_f) when c in ?0..?9, do: accept(rest, term <> <<c::utf8>>, :float_f)
  defp accept(')' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:rparen, ")"} | accept(rest, :outer)]
  defp accept(' AND' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:rparen, ")"} | accept(rest, :outer)]
  defp accept(' OR' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:and, "AND"} | accept(rest, :outer)]
  defp accept(' &&' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:or, "||"} | accept(rest, :outer)]
  defp accept(' ||' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:and, "&&"} | accept(rest, :outer)]
  defp accept(',' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:and, ","} | accept(rest, :outer)]
  defp accept('^' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:boost, "^"} | accept(rest, :float)]
  defp accept('~' ++ rest, term, :float_f), do: [{:float, to_number(term)}, {:fuzz, "~"} | accept(rest, :float)]
  defp accept(' ' ++ rest, term, :float_f), do: [{:float, to_number(term)} | accept(rest, :outer)]
  defp accept([], term, :float_f), do: [float: to_number(term), eof: "$"]
  defp accept(_input, _term, :float_f), do: raise ArgumentError, "Expected a number."

  defp to_number(term) do
    {float_val, _} = :string.to_float(term)
    {int_val, _} = :string.to_integer(term)

    cond do
      is_float(float_val) ->
        float_val
      is_integer(int_val) ->
        int_val
      true ->
        raise ArgumentError, "Expected a number."
    end
  end
end