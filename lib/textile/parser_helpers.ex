defmodule Textile.ParserHelpers do
  import Phoenix.HTML

  defmacro attribute_parser(name, open_token, close_token, open_tag, close_tag) do
    quote do
      defp unquote(name)(parser, [{unquote(open_token), open} | r_tokens]) do
        case well_formed(parser, r_tokens) do
          {:ok, tree, [{unquote(close_token), _close} | r2_tokens]} ->
            {:ok, [{:markup, unquote(open_tag)}, tree, {:markup, unquote(close_tag)}], r2_tokens}

          {:ok, tree, r2_tokens} ->
            {:ok, [{:text, escape_html(open)}, tree], r2_tokens}
        end
      end

      defp unquote(name)(parser, [{unquote(:"b_#{open_token}"), open} | r_tokens]) do
        case well_formed(parser, r_tokens) do
          {:ok, tree, [{unquote(:"b_#{close_token}"), _close} | r2_tokens]} ->
            {:ok, [{:markup, unquote(open_tag)}, tree, {:markup, unquote(close_tag)}], r2_tokens}

          {:ok, tree, r2_tokens} ->
            {:ok, [{:text, escape_html(open)}, tree], r2_tokens}
        end
      end

      defp unquote(name)(_parser, _tokens),
        do: {:error, "Expected #{unquote(name)} tag"}
    end
  end

  def remove_linefeeds(text) do
    text
    |> String.replace("\r", "")
  end

  def escape_nl2br(text) do
    text
    |> String.split("\n")
    |> Enum.map(&escape_html(&1))
    |> Enum.join("<br/>")
  end

  def escape_html(text) do
    html_escape(text) |> safe_to_string()
  end
end