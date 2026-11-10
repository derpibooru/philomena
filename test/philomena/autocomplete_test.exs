defmodule Philomena.AutocompleteTest do
  use Philomena.DataCase, async: true

  import Philomena.AutocompleteFixtures

  alias Philomena.Autocomplete
  alias Philomena.Autocomplete.Autocomplete, as: Artifact
  alias Philomena.Repo

  describe "show_compiled_autocomplete/0" do
    test "returns not-found before an artifact has been generated" do
      assert Autocomplete.show_compiled_autocomplete() == {:error, :not_found}
    end

    test "returns stored bytes unchanged because the artifact is opaque" do
      artifact = autocomplete_fixture(<<255, 0, 17>>)

      assert {:ok, loaded} = Autocomplete.show_compiled_autocomplete()
      assert loaded.created_at == artifact.created_at
      assert loaded.content == <<255, 0, 17>>
    end
  end

  describe "generate_autocomplete!/0" do
    test "atomically replaces every stale artifact with one generated row" do
      autocomplete_fixture(<<1>>)
      autocomplete_fixture(<<2>>)

      generated = Autocomplete.generate_autocomplete!()

      assert %Artifact{} = generated
      assert is_binary(generated.content)
      assert Repo.aggregate(Artifact, :count) == 1
      assert {:ok, loaded} = Autocomplete.show_compiled_autocomplete()
      assert loaded.content == generated.content
    end
  end
end
