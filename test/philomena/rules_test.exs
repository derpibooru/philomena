defmodule Philomena.RulesTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.Rules` functions.

  These pin the edit-gated index visibility (staff see hidden and internal rules,
  everyone else only the visible ones), ability-based hidden-rule visibility,
  position parsing, missing-before-forbidden precedence, and the admin-only
  create/edit/update authorization matrix.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Rules
  alias Philomena.Rules.Rule

  @ban %{reason: "Rule #0", valid_until: ~U[3000-01-01 00:00:00Z]}

  describe "safe rule service lookups" do
    test "malformed IDs and absent names do not raise" do
      assert Rules.fetch_rule("not-an-id") == {:error, :not_found}
      assert Rules.fetch_rule_by_name("No such rule") == {:error, :not_found}
    end

    test "loads an existing rule by name" do
      rule = rule_fixture()
      assert Rules.fetch_rule_by_name(rule.name) == {:ok, rule}
    end
  end

  describe "list_rules_for/1" do
    test "an admin sees hidden and internal rules alongside visible ones" do
      visible = rule_fixture()
      hidden = rule_fixture(%{hidden: true})
      internal = rule_fixture(%{internal: true})

      ids = Enum.map(Rules.list_rules_for(actor(admin_user_fixture())), & &1.id)
      assert visible.id in ids
      assert hidden.id in ids
      assert internal.id in ids
    end

    test "a regular user sees only the visible rules" do
      visible = rule_fixture()
      hidden = rule_fixture(%{hidden: true})
      internal = rule_fixture(%{internal: true})

      ids = Enum.map(Rules.list_rules_for(actor(confirmed_user_fixture())), & &1.id)
      assert visible.id in ids
      refute hidden.id in ids
      refute internal.id in ids
    end

    test "an anonymous viewer sees only the visible rules" do
      visible = rule_fixture()
      hidden = rule_fixture(%{hidden: true})

      ids = Enum.map(Rules.list_rules_for(actor()), & &1.id)
      assert visible.id in ids
      refute hidden.id in ids
    end
  end

  describe "show_rule/2" do
    test "loads a visible rule by position for an anonymous viewer" do
      rule = rule_fixture()

      assert {:ok, loaded} = Rules.show_rule(actor(), to_string(rule.position))
      assert loaded.id == rule.id
    end

    test "a hidden rule is unauthorized for a viewer who may not edit it" do
      rule = rule_fixture(%{hidden: true})

      assert Rules.show_rule(actor(confirmed_user_fixture()), to_string(rule.position)) ==
               {:error, :unauthorized}
    end

    test "an internal rule is unauthorized for a viewer who may not edit it" do
      rule = rule_fixture(%{internal: true})

      assert Rules.show_rule(actor(), to_string(rule.position)) ==
               {:error, :unauthorized}
    end

    test "an admin may show a hidden rule" do
      rule = rule_fixture(%{hidden: true})

      assert {:ok, loaded} =
               Rules.show_rule(actor(admin_user_fixture()), to_string(rule.position))

      assert loaded.id == rule.id
    end

    test "a non-integer position is not-found" do
      assert Rules.show_rule(actor(), "not-a-number") == {:error, :not_found}
    end

    test "an unknown well-formed position is not found for every actor" do
      assert Rules.show_rule(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert Rules.show_rule(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "new_rule/1" do
    test "an admin gets a blank changeset" do
      assert {:ok, %Ecto.Changeset{data: %Rule{}}} =
               Rules.new_rule(actor(admin_user_fixture()))
    end

    test "a regular user is unauthorized" do
      assert Rules.new_rule(actor(confirmed_user_fixture())) == {:error, :unauthorized}
    end

    test "an anonymous viewer is unauthorized" do
      assert Rules.new_rule(actor()) == {:error, :unauthorized}
    end
  end

  describe "create_rule/2" do
    test "an admin creates a rule and its initial version" do
      unique = System.unique_integer([:positive])

      assert {:ok, [%Rule{} = rule, _version]} =
               Rules.create_rule(actor(admin_user_fixture()), %{
                 name: "New Rule ##{unique}",
                 position: unique
               })

      assert {:ok, %Rule{}} = Rules.fetch_rule(rule.id)
    end

    test "invalid attrs are a rejected changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Rules.create_rule(actor(admin_user_fixture()), %{name: ""})

      refute changeset.valid?
    end

    test "a taken position is a rejected changeset" do
      rule = rule_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Rules.create_rule(actor(admin_user_fixture()), %{
                 name: "Another Rule",
                 position: rule.position
               })

      assert %{position: ["has already been taken"]} = errors_on(changeset)
    end

    test "a regular user is unauthorized" do
      assert Rules.create_rule(actor(confirmed_user_fixture()), %{name: "x", position: 1}) ==
               {:error, :unauthorized}
    end
  end

  describe "edit_rule/2" do
    test "an admin loads a rule and a changeset" do
      rule = rule_fixture()

      assert {:ok, {%Rule{} = loaded, %Ecto.Changeset{}}} =
               Rules.edit_rule(actor(admin_user_fixture()), to_string(rule.position))

      assert loaded.id == rule.id
    end

    test "a regular user is unauthorized" do
      rule = rule_fixture()

      assert Rules.edit_rule(actor(confirmed_user_fixture()), to_string(rule.position)) ==
               {:error, :unauthorized}
    end

    test "an unknown well-formed position is not found for every actor" do
      assert Rules.edit_rule(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert Rules.edit_rule(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "update_rule/3" do
    test "an admin updates a rule and stores a new version" do
      rule = rule_fixture()

      assert {:ok, [%Rule{} = updated, _version]} =
               Rules.update_rule(actor(admin_user_fixture()), to_string(rule.position), %{
                 title: "Updated Title"
               })

      assert updated.title == "Updated Title"
      assert {:ok, %Rule{title: "Updated Title"}} = Rules.fetch_rule(rule.id)
    end

    test "an invalid update carries the unchanged rule for re-rendering" do
      rule = rule_fixture()

      assert {:error, {%Rule{} = carried, %Ecto.Changeset{} = changeset}} =
               Rules.update_rule(actor(admin_user_fixture()), to_string(rule.position), %{
                 name: ""
               })

      assert carried.id == rule.id
      refute changeset.valid?
    end

    test "renaming to a taken name carries the unchanged rule for re-rendering" do
      rule = rule_fixture()
      other = rule_fixture()

      assert {:error, {%Rule{} = carried, changeset}} =
               Rules.update_rule(actor(admin_user_fixture()), to_string(rule.position), %{
                 name: other.name
               })

      assert carried.id == rule.id
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "a regular user is unauthorized" do
      rule = rule_fixture()

      assert Rules.update_rule(actor(confirmed_user_fixture()), to_string(rule.position), %{
               title: "Hijacked"
             }) == {:error, :unauthorized}
    end

    test "a non-integer position is not-found" do
      assert Rules.update_rule(actor(admin_user_fixture()), "not-a-number", %{title: "x"}) ==
               {:error, :not_found}
    end
  end

  describe "write access prerequisite" do
    test "forms reject bans but not missing fingerprints" do
      admin = admin_user_fixture()
      rule = rule_fixture()

      for operation <- [&Rules.new_rule/1, &Rules.edit_rule(&1, rule.position)] do
        assert operation.(actor(admin, ban: @ban)) == {:error, :ban}
        assert {:ok, _} = operation.(actor(admin, fingerprint: nil))
      end
    end

    test "mutations reject bans and missing fingerprints" do
      admin = admin_user_fixture()
      rule = rule_fixture()

      operations = [
        &Rules.create_rule(&1, %{name: "Blocked", position: -1}),
        &Rules.update_rule(&1, rule.position, %{title: "Blocked"})
      ]

      for operation <- operations do
        assert operation.(actor(admin, ban: @ban)) == {:error, :ban}
        assert operation.(actor(admin, fingerprint: nil)) == {:error, :unauthorized}
      end
    end
  end
end
