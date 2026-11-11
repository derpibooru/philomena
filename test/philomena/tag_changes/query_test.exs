defmodule Philomena.TagChanges.QueryTest do
  use ExUnit.Case, async: true

  alias Philomena.TagChanges.Query

  # Tag names are lowercased on creation and the parser downcases literal
  # values, so every name here is lowercase.
  @awkward_names [
    "safe",
    "oc:star (pony)",
    "(balanced)",
    ":)",
    "(",
    ")",
    "((a)",
    ")(",
    "oc:smile :)",
    "a*b",
    "*",
    "* *",
    "a?b",
    "?",
    ~S[say "hi"],
    ~S["],
    ~S["hi],
    "back\\slash",
    "\\",
    "trailing\\",
    "foo\\*",
    "a\\\"b",
    "foo~2",
    "foo~0.5",
    "foo~",
    "a && b",
    "a || b",
    "x || y && z",
    "a ^2",
    "a^2",
    "artist:foo",
    "-negated",
    "!bang",
    "not foo",
    "a or b",
    "a and b",
    "ünïcödé (x"
  ]

  describe "literal_term/2" do
    test "compiles back to an exact term on the field for awkward names" do
      for field <- ~W(added_tag removed_tag), name <- @awkward_names do
        assert {name, Query.compile(Query.literal_term(field, name))} ==
                 {name, {:ok, %{term: %{field => name}}}}
      end
    end

    test "uses a name the parser keeps intact verbatim" do
      assert Query.literal_term("added_tag", "safe") == "added_tag:safe"
      assert Query.literal_term("added_tag", "oc:star (pony)") == "added_tag:oc:star (pony)"
      assert Query.literal_term("removed_tag", "artist:foo") == "removed_tag:artist:foo"
    end

    test "escapes and quotes a name the parser would reinterpret" do
      assert Query.literal_term("added_tag", ":)") == ~S["added_tag::)"]
      assert Query.literal_term("added_tag", "a || b") == ~S["added_tag:a || b"]
      assert Query.literal_term("added_tag", "a*b") == ~S["added_tag:a\\*b"]
      assert Query.literal_term("added_tag", "foo~2") == ~S["added_tag:foo\\~2"]
      assert Query.literal_term("removed_tag", "back\\slash") == ~S["removed_tag:back\\\\slash"]
    end
  end
end
