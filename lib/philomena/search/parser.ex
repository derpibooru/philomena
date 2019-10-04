defmodule Philomena.Search.Parser do
  defmacro defparser(name, opts) do
    field_transforms = Keyword.get(opts, :transforms, %{}) |> Macro.escape
    field_aliases = Keyword.get(opts, :aliases, %{}) |> Macro.escape
    default_field = Keyword.fetch!(opts, :default)

    quote location: :keep do
      import Philomena.Search.Lexer
      import Philomena.Search.Helpers

      deflexer(unquote(name), unquote(opts))

      def unquote(:"#{name}_parser")(ctx, input) do
        with {:ok, tree, _1, _2, _3, _4} <- unquote(:"#{name}_lexer")(input) do
          unquote(:"#{name}_parse")(ctx, tree)
        else
          {:error, msg, _1, _2, _3, _4} ->
            {:error, msg}
        end
      end

      defp unquote(:"#{name}_parse")(ctx, tokens) do
        {tree, []} = unquote(:"#{name}_top")(ctx, tokens)

        {:ok, tree}
        # rescue
        #  e in ArgumentError ->
        #    {:error, e.message}

        #  _ ->
        #    {:error, "Parsing error."}
      end

      #
      # Predictive LL(k) parser for search grammar
      #

      defp unquote(:"#{name}_top")(_ctx, []), do: {%{match_none: %{}}, []}

      defp unquote(:"#{name}_top")(ctx, tokens), do: unquote(:"#{name}_or")(ctx, tokens)

      #
      # Boolean OR
      #

      defp unquote(:"#{name}_or")(ctx, tokens) do
        case unquote(:"#{name}_and")(ctx, tokens) do
          {left, [{:or, _} | r_tokens]} ->
            {right, rest} = unquote(:"#{name}_or")(ctx, r_tokens)
            {%{bool: %{should: [left, right]}}, rest}

          {child, rest} ->
            {child, rest}
        end
      end

      #
      # Boolean AND
      #

      defp unquote(:"#{name}_and")(ctx, tokens) do
        case unquote(:"#{name}_boost")(ctx, tokens) do
          {left, [{:and, _} | r_tokens]} ->
            {right, rest} = unquote(:"#{name}_and")(ctx, r_tokens)
            {%{bool: %{must: [left, right]}}, rest}

          {child, rest} ->
            {child, rest}
        end
      end

      #
      # Subquery score boosting
      #

      defp unquote(:"#{name}_boost")(ctx, tokens) do
        case unquote(:"#{name}_not")(ctx, tokens) do
          {child, [{:boost, _}, {:number, value} | r_tokens]} ->
            {%{function_score: %{query: child, boost_factor: value}}, r_tokens}

          {child, rest} ->
            {child, rest}
        end
      end

      #
      # Boolean NOT
      #

      defp unquote(:"#{name}_not")(ctx, [{:not, _} | r_tokens]) do
        {child, rest} = unquote(:"#{name}_not")(ctx, r_tokens)

        {%{bool: %{must_not: child}}, rest}
      end

      defp unquote(:"#{name}_not")(ctx, tokens), do: unquote(:"#{name}_group")(ctx, tokens)

      #
      # Logical grouping
      #

      defp unquote(:"#{name}_group")(ctx, [{:lparen, _} | rest]) do
        case unquote(:"#{name}_top")(ctx, rest) do
          {child, [{:rparen, _} | r_tokens]} ->
            {child, r_tokens}

          _ ->
            raise ArgumentError, "Imbalanced parentheses."
        end
      end

      defp unquote(:"#{name}_group")(_ctx, [{:rparen, _} | _rest]),
        do: raise(ArgumentError, "Imbalanced parentheses.")

      defp unquote(:"#{name}_group")(ctx, tokens), do: unquote(:"#{name}_fuzz")(ctx, tokens)

      #
      # Terms and term fuzzing
      #

      defp unquote(:"#{name}_fuzz")(ctx, tokens) do
        case tokens do
          [{:int_field, field}, {:eq, _}, {:int, value}, {:fuzz, _}, {:number, fuzz} | r_tokens] ->
            {%{
               range: %{
                 unquote(:"#{name}_alias")(field) => %{
                   gte: trunc(value - fuzz),
                   lte: trunc(value + fuzz)
                 }
               }
             }, r_tokens}

          [
            {:float_field, field},
            {:eq, _},
            {:float, value},
            {:fuzz, _},
            {:number, fuzz} | r_tokens
          ] ->
            {%{
               range: %{
                 unquote(:"#{name}_alias")(field) => %{
                   gte: trunc(value - fuzz),
                   lte: trunc(value + fuzz)
                 }
               }
             }, r_tokens}

          [
            {:literal_field, field},
            {:eq, _},
            {:text, value},
            {:fuzz, _},
            {:number, fuzz} | r_tokens
          ] ->
            {%{fuzzy: %{unquote(:"#{name}_alias")(field) => %{value: value, fuzziness: fuzz}}},
             r_tokens}

          [
            {:ngram_field, field},
            {:eq, _},
            {:text, value},
            {:fuzz, _},
            {:number, fuzz} | r_tokens
          ] ->
            {%{fuzzy: %{unquote(:"#{name}_alias")(field) => %{value: value, fuzziness: fuzz}}},
             r_tokens}

          [{:default, [text: value]}, {:fuzz, _}, {:number, fuzz} | r_tokens] ->
            {%{fuzzy: %{unquote(default_field) => %{value: value, fuzziness: fuzz}}}, r_tokens}

          _ ->
            unquote(:"#{name}_range")(ctx, tokens)
        end
      end

      #
      # Range queries
      #

      defp unquote(:"#{name}_range")(ctx, tokens) do
        case tokens do
          [{:int_field, field}, {range, _}, {:int, value} | r_tokens]
          when range in [:gt, :gte, :lt, :lte] ->
            {%{range: %{unquote(:"#{name}_alias")(field) => %{range => value}}}, r_tokens}

          [{:float_field, field}, {range, _}, {:number, value} | r_tokens]
          when range in [:gt, :gte, :lt, :lte] ->
            {%{range: %{unquote(:"#{name}_alias")(field) => %{range => value}}}, r_tokens}

          [{:date_field, field}, {range, _}, {:date, [lower, _higher]} | r_tokens]
          when range in [:gt, :gte, :lt, :lte] ->
            {%{range: %{unquote(:"#{name}_alias")(field) => %{range => lower}}}, r_tokens}

          _ ->
            unquote(:"#{name}_custom")(ctx, tokens)
        end
      end

      defp unquote(:"#{name}_custom")(ctx, tokens) do
        case tokens do
          [{:custom_field, field}, {:text, value} | r_tokens] ->
            {unquote(field_transforms)[field].(ctx, value), r_tokens}

          _ ->
            unquote(:"#{name}_term")(ctx, tokens)
        end
      end

      defp unquote(:"#{name}_term")(_ctx, tokens) do
        case tokens do
          [{:date_field, field}, {:eq, _}, {:date, [lower, higher]} | r_tokens] ->
            {%{range: %{unquote(:"#{name}_alias")(field) => %{gte: lower, lte: higher}}},
             r_tokens}

          [{:ngram_field, field}, {:eq, _}, {:text, value} | r_tokens] ->
            value = process_term(value)

            if contains_wildcard?(value) do
              {%{wildcard: %{unquote(:"#{name}_alias")(field) => unescape_wildcard(value)}},
               r_tokens}
            else
              {%{match: %{unquote(:"#{name}_alias")(field) => unescape_regular(value)}}, r_tokens}
            end

          [{:literal_field, field}, {:eq, _}, {:text, value} | r_tokens] ->
            value = process_term(value)

            if contains_wildcard?(value) do
              {%{wildcard: %{unquote(:"#{name}_alias")(field) => unescape_wildcard(value)}},
               r_tokens}
            else
              {%{term: %{unquote(:"#{name}_alias")(field) => unescape_regular(value)}}, r_tokens}
            end

          [{_field_type, field}, {:eq, _}, {_value_type, value} | r_tokens] ->
            {%{term: %{unquote(:"#{name}_alias")(field) => value}}, r_tokens}

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

      defp unquote(:"#{name}_alias")(field) do
        unquote(field_aliases)[field] || field
      end
    end
  end
end
