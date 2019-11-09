defmodule Textile.ParserHelpers do
  defmacro attribute_parser(name, open_token, close_token, open_tag, close_tag) do
    quote do
      defp unquote(name)(parser, [{unquote(open_token), open} | r_tokens]) do
        with {:ok, tree, [{unquote(close_token), _close} | r2_tokens]} <- well_formed(parser, r_tokens) do
          {:ok, [markup: unquote(open_tag)] ++ tree ++ [markup: unquote(close_tag)], r2_tokens}
        else
          _ ->
            {:ok, [text: escape_html(open)], r_tokens}
        end
      end

      defp unquote(name)(parser, [{unquote(:"b_#{open_token}"), open} | r_tokens]) do
        with {:ok, tree, [{unquote(:"b_#{close_token}"), _close} | r2_tokens]} <- well_formed(parser, r_tokens) do
          {:ok, [markup: unquote(open_tag)] ++ tree ++ [markup: unquote(close_tag)], r2_tokens}
        else
          _ ->
            {:ok, [text: escape_html(open)], r_tokens}
        end
      end

      defp unquote(name)(_parser, _tokens),
        do: {:error, "Expected #{unquote(name)} tag"}
    end
  end
end