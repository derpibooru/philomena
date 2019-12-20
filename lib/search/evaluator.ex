defmodule Search.Evaluator do
  # TODO: rethink the necessity of this module.
  # Can we do this in elasticsearch instead?

  def hits?(doc, %{bool: bool_query}) do
    must(doc, bool_query[:must]) and
      must(doc, bool_query[:filter]) and
      should(doc, bool_query[:should]) and
      not should(doc, bool_query[:must_not])
  end

  def hits?(doc, %{range: range_query}) do
    [term] = Map.keys(range_query)
    doc_values = wrap(doc[atomify(term)])

    range_query[term]
    |> Enum.all?(fn
      {:gt, query_val} ->
        Enum.any?(doc_values, & &1 > query_val)
      {:gte, query_val} ->
        Enum.any?(doc_values, & &1 >= query_val)
      {:lt, query_val} ->
        Enum.any?(doc_values, & &1 < query_val)
      {:lte, query_val} ->
        Enum.any?(doc_values, & &1 <= query_val)
    end)
  end

  def hits?(doc, %{fuzzy: fuzzy_query}) do
    [{term, %{value: query_val, fuzziness: fuzziness}}] = Enum.to_list(fuzzy_query)

    wrap(doc[atomify(term)])
    |> Enum.any?(fn doc_val ->
      cond do
        fuzziness >= 1 ->
          levenshtein(query_val, doc_val) <= fuzziness

        fuzziness >= 0 ->
          levenshtein(query_val, doc_val) <= trunc((1 - fuzziness) * byte_size(query_val))

        true ->
          false
      end
    end)
  end

  def hits?(doc, %{wildcard: wildcard_query}) do
    [{term, query_val}] = Enum.to_list(wildcard_query)
    query_re = wildcard_to_regex(query_val)

    wrap(doc[atomify(term)])
    |> Enum.any?(&Regex.match?(query_re, &1 || ""))
  end

  def hits?(doc, %{match_phrase: phrase_query}) do
    # This is wildly inaccurate but practically unavoidable as
    # there is no good reason to import a term stemmer
    [{term, query_val}] = Enum.to_list(phrase_query)

    wrap(doc[atomify(term)])
    |> Enum.any?(&String.contains?(&1, query_val))
  end

  def hits?(doc, %{term: term_query}) do
    [{term, query_val}] = Enum.to_list(term_query)

    wrap(doc[atomify(term)])
    |> Enum.member?(query_val)
  end

  def hits?(doc, %{terms: terms_query}) do
    [{term, query_vals}] = Enum.to_list(terms_query)

    wrap(doc[atomify(term)])
    |> Enum.any?(&Enum.member?(query_vals, &1))
  end

  def hits?(_doc, %{match_all: %{}}), do: true
  def hits?(_doc, %{match_none: %{}}), do: false
  def hits?(doc, %{function_score: %{query: query}}), do: hits?(doc, query)

  defp must(_doc, nil), do: true
  defp must(doc, queries) when is_list(queries), do: Enum.all?(queries, &hits?(doc, &1))
  defp must(doc, query), do: hits?(doc, query)

  defp should(_doc, nil), do: false
  defp should(doc, queries) when is_list(queries), do: Enum.any?(queries, &hits?(doc, &1))
  defp should(doc, query), do: hits?(doc, query)

  defp wrap(list) when is_list(list), do: list
  defp wrap(object), do: [object]

  defp atomify(atom) when is_atom(atom), do: atom
  defp atomify(string) when is_binary(string), do: String.to_existing_atom(string)

  def levenshtein(s1, s2) do
    {dist, _lookup} = levenshtein_lookup(s1, s2, %{}, 0)

    dist
  end

  defp levenshtein_lookup(s1, s2, lookup, times) do
    case lookup[{s1, s2}] do
      nil ->
        levenshtein_execute(s1, s2, lookup, times)

      val ->
        {val, lookup}
    end
  end

  # Avoid pursuing excessively time-consuming substrings
  defp levenshtein_execute(s1, s2, lookup, times) when times > 2, do: {max(byte_size(s1), byte_size(s2)), lookup}
  defp levenshtein_execute("", s2, lookup, _times), do: {byte_size(s2), lookup}
  defp levenshtein_execute(s1, "", lookup, _times), do: {byte_size(s1), lookup}
  defp levenshtein_execute(s1, s1, lookup, _times), do: {0, lookup}
  defp levenshtein_execute(s1, s2, lookup, times) do
    {deletion, lookup}  = levenshtein_lookup(chop(s1), s2, lookup, times + 1)
    {insertion, lookup} = levenshtein_lookup(s1, chop(s2), lookup, times + 1)
    {substitution, lookup} = levenshtein_lookup(chop(s1), chop(s2), lookup, times + 1)

    min =
      Enum.min([
        deletion + 1,
        insertion + 1,
        substitution + last_bytes_different?(s1, s2)
      ])

    lookup = Map.put(lookup, {s1, s2}, min)

    {min, lookup}
  end

  defp chop(str) when is_binary(str), do: binary_part(str, 0, byte_size(str) - 1)
  defp last_bytes_different?(s1, s2) when binary_part(s1, byte_size(s1) - 1, 1) == binary_part(s2, byte_size(s2) - 1, 1), do: 0
  defp last_bytes_different?(_s1, _s2), do: 1

  defp wildcard_to_regex(input) do
    re =
      input
      |> String.replace(~r/([.+^$\[\]\\\(\){}|-])/, "\\\\\\1") # escape regex metacharacters
      |> String.replace(~r/([^\\]|[^\\](?:\\\\)+)\*/, "\\1.*") # * -> .* (kleene star)
      |> String.replace(~r/\A(?:\\\\)*\*/, ".*")               # * -> .* (kleene star)
      |> String.replace(~r/([^\\]|[^\\](?:\\\\)+)\?/, "\\1.?") # ? -> .? (concatenation/alternation)
      |> String.replace(~r/\A(?:\\\\)*\?/, ".?")               # ? -> .? (concatenation/alternation)

    Regex.compile!("\\A#{re}\\z", "im")
  end
end
