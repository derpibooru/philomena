defmodule Philomena.Search.Parser do
  def parse(ctx, tokens) do
    {tree, []} = search_top(ctx, tokens)

    {:ok, tree}
  rescue
    e in ArgumentError ->
      {:error, e.message}

    _ ->
      {:error, "Parsing error."}
  end

  #
  # Predictive LL(k) parser for search grammar
  #
  defp search_top(ctx, tokens), do: search_or(ctx, tokens)

  #
  # Boolean OR
  #

  defp search_or(ctx, tokens) do
    case search_and(ctx, tokens) do
      {left, [{:or, _} | r_tokens]} ->
        {right, rest} = search_top(ctx, r_tokens)
        {%{bool: %{should: [left, right]}}, rest}

      {child, rest} ->
        {child, rest}
    end
  end

  #
  # Boolean AND
  #

  defp search_and(ctx, tokens) do
    case search_boost(ctx, tokens) do
      {left, [{:and, _} | r_tokens]} ->
        {right, rest} = search_top(ctx, r_tokens)
        {%{bool: %{must: [left, right]}}, rest}

      {child, rest} ->
        {child, rest}
    end
  end

  #
  # Subquery score boosting
  #

  defp search_boost(ctx, tokens) do
    case search_not(ctx, tokens) do
      {child, [{:boost, _}, {:float, value} | r_tokens]} ->
        {%{function_score: %{query: child, boost_factor: value}}, r_tokens}

      {child, rest} ->
        {child, rest}
    end
  end

  #
  # Boolean NOT
  #

  defp search_not(ctx, [{:not, _} | r_tokens]) do
    {child, rest} = search_top(ctx, r_tokens)

    {%{bool: %{must_not: child}}, rest}
  end

  defp search_not(ctx, tokens), do: search_group(ctx, tokens)

  #
  # Logical grouping
  #

  defp search_group(ctx, [{:lparen, _} | rest]) do
    case search_top(ctx, rest) do
      {child, [{:rparen, _} | r_tokens]} ->
        {child, r_tokens}

      _ ->
        raise ArgumentError, "Imbalanced parentheses."
    end
  end

  defp search_group(_ctx, [{:rparen, _} | _rest]),
    do: raise(ArgumentError, "Imbalanced parentheses.")

  defp search_group(ctx, tokens), do: search_fuzz(ctx, tokens)

  #
  # Term fuzzing
  #

  defp search_fuzz(ctx, tokens) do
    search_term(ctx, tokens)
  end

  #
  # Search terms
  #

  defp search_term(_ctx, [{:term, _t} | rest]) do
    {[], rest}
  end

  defp search_term(_ctx, []), do: raise(ArgumentError, "Expected a term, got <end of input>.")

  defp search_term(_ctx, [{_, text} | _rest]),
    do: raise(ArgumentError, "Expected a term, got `#{text}'.")
end
