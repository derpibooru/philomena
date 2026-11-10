defmodule PhilomenaQuery.Search.MappingDiffTest do
  use ExUnit.Case, async: true

  alias PhilomenaQuery.Search.MappingDiff

  @desired %{
    settings: %{
      index: %{
        number_of_shards: 5,
        max_result_window: 10_000_000,
        analysis: %{
          analyzer: %{
            tag_snowball: %{tokenizer: :letter, filter: [:asciifolding, :snowball]}
          }
        }
      }
    },
    mappings: %{
      dynamic: false,
      properties: %{
        id: %{type: "integer"},
        name: %{type: "keyword"},
        analyzed_name: %{
          type: "text",
          fields: %{nlp: %{type: "text", analyzer: "tag_snowball"}}
        }
      }
    }
  }

  # What the engine hands back after `@desired` is created: string keys,
  # stringified settings values and `dynamic`, server-generated settings
  # entries, and the `_meta` block written at creation time.
  @live %{
    settings: %{
      "index" => %{
        "number_of_shards" => "5",
        "max_result_window" => "10000000",
        "analysis" => %{
          "analyzer" => %{
            "tag_snowball" => %{
              "tokenizer" => "letter",
              "filter" => ["asciifolding", "snowball"]
            }
          }
        },
        "uuid" => "F_ne0oB0Rvqto0dciRDdmw",
        "provided_name" => "test_tags_v1",
        "creation_date" => "1710000000000",
        "version" => %{"created" => "136217927"},
        "replication" => %{"type" => "DOCUMENT"}
      }
    },
    mapping: %{
      "dynamic" => "false",
      "_meta" => %{"version" => 1},
      "properties" => %{
        "id" => %{"type" => "integer"},
        "name" => %{"type" => "keyword"},
        "analyzed_name" => %{
          "type" => "text",
          "fields" => %{"nlp" => %{"type" => "text", "analyzer" => "tag_snowball"}}
        }
      }
    }
  }

  test "identical definitions are :equal despite engine normalization" do
    assert MappingDiff.classify(@live, @desired) == :equal
  end

  test "a new property is :additive" do
    desired = put_in(@desired, [:mappings, :properties, :new_field], %{type: "boolean"})

    assert MappingDiff.classify(@live, desired) == :additive
  end

  test "a changed property type is :rebuild" do
    desired = put_in(@desired, [:mappings, :properties, :id], %{type: "keyword"})

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "a changed nested sub-field is :rebuild" do
    desired =
      put_in(
        @desired,
        [:mappings, :properties, :analyzed_name, :fields, :nlp, :analyzer],
        "snowball"
      )

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "a removed property is :rebuild, even alongside additions" do
    desired =
      @desired
      |> update_in([:mappings, :properties], &Map.delete(&1, :name))
      |> put_in([:mappings, :properties, :new_field], %{type: "boolean"})

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "a changed dynamic flag is :rebuild" do
    desired = put_in(@desired, [:mappings, :dynamic], true)

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "a changed settings value is :rebuild" do
    desired = put_in(@desired, [:settings, :index, :number_of_shards], 6)

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "a changed analyzer definition is :rebuild" do
    desired =
      put_in(
        @desired,
        [:settings, :index, :analysis, :analyzer, :tag_snowball, :filter],
        [:snowball]
      )

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "a new settings entry is :rebuild" do
    desired = put_in(@desired, [:settings, :index, :refresh_interval], "10s")

    assert MappingDiff.classify(@live, desired) == :rebuild
  end

  test "server-generated settings entries do not affect classification" do
    # `uuid`, `creation_date` etc. exist only on the live side and are ignored
    # by the subset comparison; this is implicit in the other tests but pin it
    # explicitly for a minimal desired definition.
    desired = %{
      settings: %{index: %{number_of_shards: 5}},
      mappings: %{dynamic: false, properties: %{id: %{type: "integer"}}}
    }

    live = %{
      settings: %{"index" => %{"number_of_shards" => "5", "uuid" => "abc"}},
      mapping: %{
        "dynamic" => "false",
        "_meta" => %{"version" => 3},
        "properties" => %{"id" => %{"type" => "integer"}}
      }
    }

    assert MappingDiff.classify(live, desired) == :equal
  end
end
