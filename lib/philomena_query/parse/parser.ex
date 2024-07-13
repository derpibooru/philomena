defmodule PhilomenaQuery.Parse.Parser do
  @moduledoc """
  A search language for safely evaluating user-input queries.

  The query language supports the following features:
  - Disjunction (OR/||)
  - Conjunction (AND/&&/,)
  - Negation (NOT/-/!)
  - Expression boosting
  - Parenthetical grouping

  Several types of terms are supported:
  - Booleans
  - Dates (absolute and relative, time points and ranges)
  - Floats
  - Integers
  - IP Addresses
  - Literal text
  - Stemmed text

  Specific terms can support the following features:
  - Range queries (.lte/.lt/.gte/.gt)
  - Fuzzing (~0.5)
  - Wildcarding (*?)
  - CIDR masks (/27)

  The rich search expression grammar is arguably a defining feature of Philomena, and its
  feature set makes it stand out in comparison to traditional boorus.
  """

  alias PhilomenaQuery.Parse.{
    BoolParser,
    DateParser,
    FloatParser,
    IntParser,
    IpParser,
    Lexer,
    LiteralParser,
    NgramParser,
    Parser,
    TermRangeParser
  }

  @typedoc """
  User-supplied context argument.

  Provided to `parse/3` and passed to the transform callback.
  """
  @type context :: any()

  @typedoc "Query in the search engine JSON query language."
  @type query :: map()

  @typedoc "Whether the default field is `:term` (not analyzed) or `:ngram` (analyzed)."
  @type default_field_type :: :term | :ngram

  @typedoc """
  Return value of the transform callback.

  On `{:ok, query}`, the query is incorporated into the parse tree at the current location.
  On `{:error, error}`, parsing immediately stops and the error is returned from the parser.
  """
  @type transform_result :: {:ok, query()} | {:error, String.t()}

  @typedoc """
  Type of the transform callback.

  The transform callback receives the context argument passed to `parse/3` and the remainder of
  the term. For instance `my:example` would match a transform rule with the key `"my"`, and
  the remainder passed to the callback would be `"example"`.
  """
  @type transform :: (context, String.t() -> transform_result())

  @type t :: %__MODULE__{
          default_field: {String.t(), default_field_type()},
          bool_fields: [String.t()],
          date_fields: [String.t()],
          float_fields: [String.t()],
          int_fields: [String.t()],
          ip_fields: [String.t()],
          literal_fields: [String.t()],
          ngram_fields: [String.t()],
          custom_fields: [String.t()],
          transforms: %{String.t() => transform()},
          aliases: %{String.t() => String.t()},
          no_downcase_fields: [String.t()],
          __fields__: map(),
          __data__: context()
        }

  defstruct [
    :default_field,
    bool_fields: [],
    date_fields: [],
    float_fields: [],
    int_fields: [],
    ip_fields: [],
    literal_fields: [],
    ngram_fields: [],
    custom_fields: [],
    transforms: %{},
    aliases: %{},
    no_downcase_fields: [],
    __fields__: %{},
    __data__: nil
  ]

  @max_clause_count 512

  @doc """
  Creates a `Parser` suitable for safely parsing user-input queries.

  Fields refer to attributes of the indexed document which will be searchable with
  `m:PhilomenaQuery.Search`.

  Available options:
  - `bool_fields` - a list of field names parsed as booleans
  - `float_fields` - a list of field names parsed as floats
  - `int_fields` - a list of field names parsed as integers
  - `ip_fields` - a list of field names parsed as IP CIDR masks
  - `literal_fields` - wildcardable fields which are searched as the exact value
  - `ngram_fields` - wildcardable fields which are searched as stemmed values
  - `custom_fields` - fields which do not exist on the document and are created by a callback
  - `transforms` - a map of custom field names to transform functions
  - `aliases` - a map of field names to the names they should have in the search engine
  - `no_downcase_fields` - a list of field names which do not have string downcasing applied

  ## Example

      options = [
        bool_fields: ["hidden"],
        custom_fields: ["example"],
        transforms: %{"example" => fn _ctx, term -> %{term: %{term => "example"}} end},
        aliases: %{"hidden" => "hidden_from_users"}
      ]

      Parser.new(options)

  """
  @spec new(keyword()) :: t()
  def new(options) do
    parser = struct(Parser, options)

    fields =
      Enum.map(parser.bool_fields, fn f -> {f, BoolParser} end) ++
        Enum.map(parser.date_fields, fn f -> {f, DateParser} end) ++
        Enum.map(parser.float_fields, fn f -> {f, FloatParser} end) ++
        Enum.map(parser.int_fields, fn f -> {f, IntParser} end) ++
        Enum.map(parser.ip_fields, fn f -> {f, IpParser} end) ++
        Enum.map(parser.literal_fields, fn f -> {f, LiteralParser} end) ++
        Enum.map(parser.ngram_fields, fn f -> {f, NgramParser} end) ++
        Enum.map(parser.custom_fields, fn f -> {f, :custom_field} end)

    %{parser | __fields__: Map.new(fields)}
  end

  @doc """
  Parse the query into a definition suitable for the search engine.

  The parser argument should have been created with a previous call to `parser/1`. When the
  `context` argument is passed, it becomes the first argument to any transform functions defined
  in the `transform` option.

  ## Example

      iex> Parser.parse(parser, "safe")
      {:ok, %{term: %{"namespaced_tags.name" => "safe"}}}

      iex> Parser.parse(nil, "safe OR solo")
      {:ok,
       %{
         bool: %{
           should: [
             %{term: %{"namespaced_tags.name" => "safe"}},
             %{term: %{"namespaced_tags.name" => "solo"}}
           ]
         }
       }}

      iex> Parser.parse(parser, ")")
      {:error, "Imbalanced parentheses."}

  """
  @spec parse(t(), String.t(), context()) :: {:ok, query()} | {:error, String.t()}
  def parse(parser, input, context \\ nil)

  def parse(%Parser{} = parser, input, context) do
    parser = %{parser | __data__: context}

    with {:ok, input} <- coerce_string(input),
         {:ok, tokens, _1, _2, _3, _4} <- Lexer.lex(input),
         {:ok, tokens} <- convert_empty_token_list(tokens),
         {:ok, {tree, []}} <- search_top(parser, tokens) do
      {:ok, tree}
    else
      {:error, :empty_query} ->
        {:ok, %{match_none: %{}}}

      {:ok, {_tree, tokens}} ->
        {:error, "junk at end of expression: " <> debug_tokens(tokens)}

      {:error, msg, start_pos, _1, _2, _3} ->
        {:error, msg <> ", starting at: " <> start_pos}

      {:error, msg} ->
        {:error, msg}

      err ->
        err
        # {:error, "unknown parsing error"}
    end
  end

  defp coerce_string(term) when is_binary(term), do: {:ok, term}
  defp coerce_string(nil), do: {:ok, ""}
  defp coerce_string(_), do: {:error, "search query is not a string"}

  defp convert_empty_token_list([]), do: {:error, :empty_query}
  defp convert_empty_token_list(tokens), do: {:ok, tokens}

  defp debug_tokens(tokens) do
    Enum.map_join(tokens, fn {_k, v} -> v end)
  end

  #
  # Predictive LL(1) RD parser for search grammar
  #

  defp search_top(parser, tokens), do: search_or(parser, tokens)

  defp search_or(parser, tokens) do
    with {:ok, {left, [{:or, _} | r_tokens]}} <- search_and(parser, tokens),
         {:ok, {right, rest}} <- search_or(parser, r_tokens) do
      {:ok, {flatten_disjunction_child(left, right), rest}}
    else
      value ->
        value
    end
  end

  defp search_and(parser, tokens) do
    with {:ok, {left, [{:and, _} | r_tokens]}} <- search_boost(parser, tokens),
         {:ok, {right, rest}} <- search_and(parser, r_tokens) do
      {:ok, {flatten_conjunction_child(left, right), rest}}
    else
      value ->
        value
    end
  end

  defp search_boost(parser, tokens) do
    case search_not(parser, tokens) do
      {:ok, {child, [{:boost, value} | r_tokens]}} when value >= 0 ->
        {:ok, {%{function_score: %{query: child, boost: value}}, r_tokens}}

      {:ok, {_child, [{:boost, _value} | _r_tokens]}} ->
        {:error, "Boost value must be non-negative."}

      value ->
        value
    end
  end

  defp search_not(parser, [{:not, _} | rest]) do
    case search_group(parser, rest) do
      {:ok, {child, r_tokens}} ->
        {:ok, {flatten_negation_child(child), r_tokens}}

      value ->
        value
    end
  end

  defp search_not(parser, tokens), do: search_group(parser, tokens)

  defp search_group(parser, [{:lparen, _} | rest]) do
    case search_top(parser, rest) do
      {:ok, {child, [{:rparen, _} | r_tokens]}} ->
        {:ok, {child, r_tokens}}

      {:ok, {_child, _tokens}} ->
        {:error, "Imbalanced parentheses."}

      value ->
        value
    end
  end

  defp search_group(_parser, [{:rparen, _} | _rest]) do
    {:error, "Imbalanced parentheses."}
  end

  defp search_group(parser, tokens), do: search_field(parser, tokens)

  defp search_field(parser, [{:term, value} | r_tokens]) do
    tokens = TermRangeParser.parse(value, parser.__fields__, parser.default_field)

    case field_top(parser, tokens) do
      {:ok, {child, []}} ->
        {:ok, {child, r_tokens}}

      err ->
        err
    end
  end

  defp search_field(_parser, _tokens), do: {:error, "Expected a term."}

  #
  # Predictive LL(k) RD parser for search terms in parent grammar
  #

  defp field_top(parser, tokens), do: field_term(parser, tokens)

  defp field_term(parser, custom_field: field_name, range: :eq, value: value) do
    case parser.transforms[field_name].(parser.__data__, String.trim(value)) do
      {:ok, child} ->
        {:ok, {child, []}}

      err ->
        err
    end
  end

  defp field_term(parser, [{field_parser, field_name}, {:range, range}, {:value, value}]) do
    # N.B.: field_parser is an atom
    case field_parser.parse(value) do
      {:ok, extra_tokens, _1, _2, _3, _4} ->
        field_type(parser, [{field_parser, field_name}, {:range, range}] ++ extra_tokens)

      err ->
        err
    end
  end

  # Types which do not support ranges

  defp field_type(parser, [{LiteralParser, field_name}, range: :eq, literal: value]),
    do:
      {:ok,
       {%{term: %{field(parser, field_name) => normalize_value(parser, field_name, value)}}, []}}

  defp field_type(parser, [{LiteralParser, field_name}, range: :eq, literal: value, fuzz: fuzz]),
    do:
      {:ok,
       {%{
          fuzzy: %{
            field(parser, field_name) => %{
              value: normalize_value(parser, field_name, value),
              fuzziness: fuzz
            }
          }
        }, []}}

  defp field_type(_parser, [{LiteralParser, _field_name}, range: :eq, wildcard: "*"]),
    do: {:ok, {%{match_all: %{}}, []}}

  defp field_type(parser, [{LiteralParser, field_name}, range: :eq, wildcard: value]),
    do:
      {:ok,
       {%{wildcard: %{field(parser, field_name) => normalize_value(parser, field_name, value)}},
        []}}

  defp field_type(parser, [{NgramParser, field_name}, range: :eq, literal: value]),
    do:
      {:ok,
       {%{
          match_phrase: %{field(parser, field_name) => normalize_value(parser, field_name, value)}
        }, []}}

  defp field_type(parser, [{NgramParser, field_name}, range: :eq, literal: value, fuzz: _fuzz]),
    do:
      {:ok,
       {%{
          match_phrase: %{field(parser, field_name) => normalize_value(parser, field_name, value)}
        }, []}}

  defp field_type(_parser, [{NgramParser, _field_name}, range: :eq, wildcard: "*"]),
    do: {:ok, {%{match_all: %{}}, []}}

  defp field_type(parser, [{NgramParser, field_name}, range: :eq, wildcard: value]),
    do:
      {:ok,
       {%{wildcard: %{field(parser, field_name) => normalize_value(parser, field_name, value)}},
        []}}

  defp field_type(parser, [{BoolParser, field_name}, range: :eq, bool: value]),
    do: {:ok, {%{term: %{field(parser, field_name) => value}}, []}}

  defp field_type(parser, [{IpParser, field_name}, range: :eq, ip: value]),
    do: {:ok, {%{term: %{field(parser, field_name) => value}}, []}}

  # Types which do support ranges

  defp field_type(parser, [{IntParser, field_name}, range: :eq, int: value]),
    do: {:ok, {%{term: %{field(parser, field_name) => value}}, []}}

  defp field_type(parser, [{IntParser, field_name}, range: :eq, int_range: [lower, upper]]),
    do: {:ok, {%{range: %{field(parser, field_name) => %{gte: lower, lte: upper}}}, []}}

  defp field_type(parser, [{IntParser, field_name}, range: range, int: value]),
    do: {:ok, {%{range: %{field(parser, field_name) => %{range => value}}}, []}}

  defp field_type(_parser, [{IntParser, field_name}, range: _range, int_range: _value]),
    do: {:error, "multiple ranges specified for " <> field_name}

  defp field_type(parser, [{FloatParser, field_name}, range: :eq, float: value]),
    do: {:ok, {%{term: %{field(parser, field_name) => value}}, []}}

  defp field_type(parser, [{FloatParser, field_name}, range: :eq, float_range: [lower, upper]]),
    do: {:ok, {%{range: %{field(parser, field_name) => %{gte: lower, lte: upper}}}, []}}

  defp field_type(parser, [{FloatParser, field_name}, range: range, float: value]),
    do: {:ok, {%{range: %{field(parser, field_name) => %{range => value}}}, []}}

  defp field_type(_parser, [{FloatParser, field_name}, range: _range, float_range: _value]),
    do: {:error, "multiple ranges specified for " <> field_name}

  defp field_type(parser, [{DateParser, field_name}, range: :eq, date: [lower, upper]]),
    do: {:ok, {%{range: %{field(parser, field_name) => %{gte: lower, lt: upper}}}, []}}

  defp field_type(parser, [{DateParser, field_name}, range: r, date: [_lower, upper]])
       when r in [:lte, :gt],
       do: {:ok, {%{range: %{field(parser, field_name) => %{r => upper}}}, []}}

  defp field_type(parser, [{DateParser, field_name}, range: r, date: [lower, _upper]])
       when r in [:gte, :lt],
       do: {:ok, {%{range: %{field(parser, field_name) => %{r => lower}}}, []}}

  defp field(parser, field_name) do
    parser.aliases[field_name] || field_name
  end

  defp normalize_value(parser, field_name, value) do
    value
    |> String.trim()
    |> maybe_downcase(parser, field_name)
  end

  defp maybe_downcase(value, parser, field_name) do
    if Enum.member?(parser.no_downcase_fields, field_name) do
      value
    else
      String.downcase(value)
    end
  end

  # Flattens the child of a disjunction or conjunction to improve performance.
  defp flatten_disjunction_child(this_child, %{bool: %{should: next_child}} = child)
       when child == %{bool: %{should: next_child}} and is_list(next_child) and
              length(next_child) <= @max_clause_count,
       do: %{bool: %{should: [this_child | next_child]}}

  defp flatten_disjunction_child(this_child, next_child),
    do: %{bool: %{should: [this_child, next_child]}}

  defp flatten_conjunction_child(this_child, %{bool: %{must: next_child}} = child)
       when child == %{bool: %{must: next_child}} and is_list(next_child) and
              length(next_child) <= @max_clause_count,
       do: %{bool: %{must: [this_child | next_child]}}

  defp flatten_conjunction_child(this_child, next_child),
    do: %{bool: %{must: [this_child, next_child]}}

  # Flattens the child of a negation to eliminate double negation.
  defp flatten_negation_child(%{bool: %{must_not: next_child}} = child)
       when child == %{bool: %{must_not: next_child}} and is_map(next_child),
       do: next_child

  defp flatten_negation_child(next_child),
    do: %{bool: %{must_not: next_child}}
end
