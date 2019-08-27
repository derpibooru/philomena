defmodule Philomena.Search.Parser do
  defmacro __using__(opts) do
    lexer_name = :"#{Keyword.fetch!(opts, :name)}_lexer"
    parser_name = :"#{Keyword.fetch!(opts, :name)}_parser"
    field_transforms = Keyword.get(opts, :transforms, %{})
    field_aliases = Keyword.get(opts, :aliases, %{})
    default_field = Keyword.fetch!(opts, :default)

    quote location: :keep do
      use Philomena.Search.Lexer, unquote(opts)

      def unquote(parser_name)(ctx, input) do
        with {:ok, tree, _1, _2, _3, _4} <- unquote(lexer_name)(input) do
          parse(ctx, tree)
        else
          {:error, msg, _1, _2, _3, _4} ->
            {:error, msg}
        end
      end

      defp parse(ctx, tokens) do
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
            {right, rest} = search_or(ctx, r_tokens)
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
            {right, rest} = search_and(ctx, r_tokens)
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
          {child, [{:boost, _}, {:number, value} | r_tokens]} ->
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
      # Terms and term fuzzing
      #

      defp search_fuzz(ctx, tokens) do
        case tokens do
          [{:int_field, field}, {:eq, _}, {:int, value}, {:fuzz, _}, {:number, fuzz} | r_tokens] ->
            {%{
               range: %{try_alias(field) => %{gte: trunc(value - fuzz), lte: trunc(value + fuzz)}}
             }, r_tokens}

          [
            {:float_field, field},
            {:eq, _},
            {:float, value},
            {:fuzz, _},
            {:number, fuzz} | r_tokens
          ] ->
            {%{
               range: %{try_alias(field) => %{gte: trunc(value - fuzz), lte: trunc(value + fuzz)}}
             }, r_tokens}

          [
            {:literal_field, field},
            {:eq, _},
            {:text, value},
            {:fuzz, _},
            {:number, fuzz} | r_tokens
          ] ->
            {%{fuzzy: %{try_alias(field) => %{value: value, fuzziness: fuzz}}}, r_tokens}

          [
            {:ngram_field, field},
            {:eq, _},
            {:text, value},
            {:fuzz, _},
            {:number, fuzz} | r_tokens
          ] ->
            {%{fuzzy: %{try_alias(field) => %{value: value, fuzziness: fuzz}}}, r_tokens}

          [{:default, [text: value]}, {:fuzz, _}, {:number, fuzz} | r_tokens] ->
            {%{fuzzy: %{unquote(default_field) => %{value: value, fuzziness: fuzz}}}, r_tokens}

          _ ->
            search_range(ctx, tokens)
        end
      end

      #
      # Range queries
      #

      defp search_range(ctx, tokens) do
        case tokens do
          [{:int_field, field}, {range, _}, {:int, value} | r_tokens]
          when range in [:gt, :gte, :lt, :lte] ->
            {%{range: %{try_alias(field) => %{range => value}}}, r_tokens}

          [{:float_field, field}, {range, _}, {:number, value} | r_tokens]
          when range in [:gt, :gte, :lt, :lte] ->
            {%{range: %{try_alias(field) => %{range => value}}}, r_tokens}

          [{:date_field, field}, {range, _}, {:date, [lower, _higher]} | r_tokens]
          when range in [:gt, :gte, :lt, :lte] ->
            {%{range: %{try_alias(field) => %{range => lower}}}, r_tokens}

          _ ->
            search_custom(ctx, tokens)
        end
      end

      defp search_custom(ctx, tokens) do
        case tokens do
          [{:custom_field, field}, {:text, value} | r_tokens] ->
            {unquote(field_transforms)[field].(ctx, value), r_tokens}

          _ ->
            search_term(ctx, tokens)
        end
      end

      defp search_term(_ctx, tokens) do
        case tokens do
          [{:date_field, field}, {:eq, _}, {:date, [lower, higher]} | r_tokens] ->
            {%{range: %{try_alias(field) => %{gte: lower, lte: higher}}}, r_tokens}

          [{:ngram_field, field}, {:eq, _}, {:text, value} | r_tokens] ->
            value = process_term(value)

            if contains_wildcard?(value) do
              {%{wildcard: %{try_alias(field) => unescape_wildcard(value)}}, r_tokens}
            else
              {%{match: %{try_alias(field) => unescape_regular(value)}}, r_tokens}
            end

          [{:literal_field, field}, {:eq, _}, {:text, value} | r_tokens] ->
            value = process_term(value)

            if contains_wildcard?(value) do
              {%{wildcard: %{try_alias(field) => unescape_wildcard(value)}}, r_tokens}
            else
              {%{term: %{try_alias(field) => unescape_regular(value)}}, r_tokens}
            end

          [{_field_type, field}, {:eq, _}, {_value_type, value} | r_tokens] ->
            {%{term: %{try_alias(field) => value}}, r_tokens}

          [{:default, [text: value]} | r_tokens] ->
            value = process_term(value)

            if contains_wildcard?(value) do
              {%{wildcard: %{unquote(default_field) => unescape_wildcard(value)}}, r_tokens}
            else
              {%{term: %{unquote(default_field) => unescape_regular(value)}}, r_tokens}
            end

          _ ->
            raise ArgumentError, "Expected a term"
        end
      end

      defp contains_wildcard?(value) do
        String.match?(value, ~r/(?<!\\)(?:\\\\)*[\*\?]/)
      end

      defp unescape_wildcard(value) do
        # '*' and '?' are wildcard characters in the right context;
        # don't unescape them.
        Regex.replace(~r/(?<!\\)(?:\\)*([^\\\*\?])/, value, "\\1")
      end

      defp unescape_regular(value) do
        Regex.replace(~r/(?<!\\)(?:\\)*(.)/, value, "\\1")
      end

      defp process_term(term) do
        term |> String.trim() |> String.downcase()
      end

      defp try_alias(field) do
        unquote(field_aliases)[field] || field
      end
    end
  end
end
