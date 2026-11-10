defmodule PhilomenaWeb.RuleControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The read-only actions (:index, :show) and the staff-facing write
  # actions (:new, :create, :edit, :update) are covered here.

  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Rules.Rule
  alias Philomena.Rules.RuleVersion
  alias Philomena.Repo

  import Ecto.Query, only: [from: 2]

  # Rules are authorized against Rule, on which only admins have the write
  # abilities - regular users and moderators (plain or role_map) have only
  # :index/:show. The write routes sit in the require_authenticated_user
  # scope, so anonymous users are bounced to login before authorization runs.

  defp valid_rule_params(extra \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(extra, %{
      "name" => "Created Rule ##{unique}",
      "position" => Integer.to_string(unique)
    })
  end

  describe "GET /rules" do
    test "renders visible rules for anonymous users", %{conn: conn} do
      rule = rule_fixture(%{name: "Test Rule: be excellent", description: "Be excellent."})

      conn = get(conn, ~p"/rules")
      response = html_response(conn, 200)

      assert response =~ "Site Rules"
      assert response =~ "Test Rule: be excellent"
      assert response =~ "Be excellent."
      assert response =~ ~p"/rules/#{rule}"
    end

    test "does not list hidden or internal rules to anonymous users", %{conn: conn} do
      _visible = rule_fixture(%{name: "Test Visible Rule"})
      _hidden = rule_fixture(%{name: "Test Hidden Rule", hidden: true})
      _internal = rule_fixture(%{name: "Test Internal Rule", internal: true})

      conn = get(conn, ~p"/rules")
      response = html_response(conn, 200)

      assert response =~ "Test Visible Rule"
      refute response =~ "Test Hidden Rule"
      refute response =~ "Test Internal Rule"
    end

    test "lists hidden and internal rules to admins", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      _hidden = rule_fixture(%{name: "Test Hidden Rule", hidden: true})
      _internal = rule_fixture(%{name: "Test Internal Rule", internal: true})

      conn = get(conn, ~p"/rules")
      response = html_response(conn, 200)

      assert response =~ "Test Hidden Rule"
      assert response =~ "Test Internal Rule"
      assert response =~ "Create New Rule"
    end

    test "renders rule management affordances only to admins", %{conn: conn} do
      rule = rule_fixture(%{name: "Rule Management Marker"})

      anonymous_response = html_response(get(conn, ~p"/rules"), 200)
      refute anonymous_response =~ ~p"/rules/#{rule}/edit"
      refute anonymous_response =~ "Create New Rule"

      moderator_response =
        html_response(get(log_in_user(conn, moderator_user_fixture()), ~p"/rules"), 200)

      refute moderator_response =~ ~p"/rules/#{rule}/edit"
      refute moderator_response =~ "Create New Rule"

      admin_response =
        html_response(get(log_in_user(conn, admin_user_fixture()), ~p"/rules"), 200)

      assert admin_response =~ ~p"/rules/#{rule}/edit"
      assert admin_response =~ "Create New Rule"
    end

    test "renders an empty index when no rules exist", %{conn: conn} do
      # NOTE: the index now omits the "last updated" line when there are no
      # rules instead of raising Enum.EmptyError on the empty table.
      conn = get(conn, ~p"/rules")

      assert html_response(conn, 200) =~ "Site Rules"
    end
  end

  describe "GET /rules/:position" do
    test "renders a visible rule for anonymous users", %{conn: conn} do
      rule = rule_fixture(%{name: "Test Rule: tag your uploads"})

      conn = get(conn, ~p"/rules/#{rule}")
      response = html_response(conn, 200)

      assert response =~ "Viewing details of"
      assert response =~ "Test Rule: tag your uploads"
      assert response =~ "Revision history for this rule is unavailable"
    end

    test "renders an AST pretty diff of a rule's edited description", %{conn: conn} do
      rule = rule_fixture(%{name: "Test Rule: diff", description: "The original rule text"})

      actor =
        Philomena.AttributionFixtures.actor(Philomena.UsersFixtures.admin_user_fixture())

      {:ok, _} =
        Philomena.Rules.update_rule(actor, rule.position, %{
          "description" => "The updated rule text"
        })

      conn = get(conn, ~p"/rules/#{rule}")
      response = html_response(conn, 200)

      # The description renders as a line-by-line unified diff table over the
      # raw markdown source. The cell text is the escaped source, so the
      # unchanged suffix "rule text" appears literally in the diff__text cell
      # rather than inside rendered markup.
      assert response =~ ~s(<table class="diff">)
      assert response =~ ~s(<del class="diff__hl">)
      assert response =~ ~s(<ins class="diff__hl">)
      assert response =~ "original"
      assert response =~ "updated"
      assert response =~ "rule text</td>"
    end

    test "rejects a hidden rule as unauthorized for an anonymous viewer", %{conn: conn} do
      rule = rule_fixture(%{name: "Test Hidden Rule", hidden: true})

      conn = get(conn, ~p"/rules/#{rule}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders a hidden rule for admins", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Test Hidden Rule", hidden: true})

      conn = get(conn, ~p"/rules/#{rule}")
      response = html_response(conn, 200)

      assert response =~ "Test Hidden Rule"
    end

    test "redirects with not-found for an unknown position", %{conn: conn} do
      conn = get(conn, ~p"/rules/999999")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects to / with the not-found flash for a non-integer position", %{conn: conn} do
      conn = get(conn, ~p"/rules/not-a-position")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end

  describe "GET /rules/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/rules/new")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "redirects to / for a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/rules/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for a plain moderator", %{conn: conn} do
      # NOTE: moderators have only :index/:show on rules - no write ability -
      # so even a plain moderator is turned away from the staff rule forms.
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/rules/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/rules/new")

      assert html_response(conn, 200) =~ "Creating a new rule"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/rules/new")

      assert html_response(conn, 200) =~ "Creating a new rule"
    end
  end

  describe "POST /rules (create)" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = post(conn, ~p"/rules", %{"rule" => valid_rule_params()})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      params = valid_rule_params(%{"name" => "Nope Rule"})
      conn = post(conn, ~p"/rules", %{"rule" => params})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(Rule, name: "Nope Rule")
    end

    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      params = valid_rule_params(%{"name" => "Nope Mod Rule"})
      conn = post(conn, ~p"/rules", %{"rule" => params})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(Rule, name: "Nope Mod Rule")
    end

    test "creates a rule (with a version) as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      params = valid_rule_params(%{"name" => "Admin Created Rule"})
      conn = post(conn, ~p"/rules", %{"rule" => params})

      rule = Repo.get_by(Rule, name: "Admin Created Rule")
      assert rule
      assert redirected_to(conn) == ~p"/rules/#{rule}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "created successfully"
      # The create path records the initial version, attributed to the admin.
      assert Repo.get_by(RuleVersion, rule_id: rule.id)
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      # A blank name fails Rule.changeset's validate_required.
      params = valid_rule_params(%{"name" => ""})
      conn = post(conn, ~p"/rules", %{"rule" => params})

      assert html_response(conn, 200) =~ "Creating a new rule"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/rules", %{
          "rule" => valid_rule_params(%{"name" => "Fingerprintless Rule"})
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Rule, name: "Fingerprintless Rule")
    end
  end

  describe "GET /rules/:position/edit" do
    test "rejects a regular user", %{conn: conn} do
      rule = rule_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/rules/#{rule}/edit")

      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Editable Rule"})

      conn = get(conn, ~p"/rules/#{rule}/edit")
      response = html_response(conn, 200)

      assert response =~ "Editing"
      assert response =~ "Editable Rule"
    end

    test "redirects with a not-found flash on an unknown position for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/rules/999999/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking"
    end

    test "redirects to / with the not-found flash for a non-integer position", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/rules/not-a-position/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking"
    end

    test "renders the edit form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Editable Rule"})
      conn = get(without_fingerprint(conn), ~p"/rules/#{rule}/edit")

      assert html_response(conn, 200) =~ "Editable Rule"
    end
  end

  describe "PATCH /rules/:position (update)" do
    test "rejects a regular user", %{conn: conn} do
      rule = rule_fixture(%{name: "Original Rule Name"})
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = patch(conn, ~p"/rules/#{rule}", %{"rule" => %{"name" => "Hacked"}})

      assert redirected_to(conn) == "/"
      assert Repo.get(Rule, rule.id).name == "Original Rule Name"
    end

    test "updates the rule (with a version) as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Original Rule Name"})

      conn =
        patch(conn, ~p"/rules/#{rule}", %{
          "rule" => %{"name" => "Renamed Rule", "position" => Integer.to_string(rule.position)}
        })

      assert redirected_to(conn) == ~p"/rules/#{rule}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "updated successfully"
      assert Repo.get(Rule, rule.id).name == "Renamed Rule"
      # Each edit stores a new version row (one for the fixture, one for this edit).
      assert Repo.aggregate(from(v in RuleVersion, where: v.rule_id == ^rule.id), :count) == 2
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Original Rule Name"})

      conn =
        patch(conn, ~p"/rules/#{rule}", %{
          "rule" => %{"name" => "", "position" => Integer.to_string(rule.position)}
        })

      assert html_response(conn, 200) =~ "Editing"
      assert Repo.get(Rule, rule.id).name == "Original Rule Name"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Original Rule Name"})

      conn =
        patch(without_fingerprint(conn), ~p"/rules/#{rule}", %{
          "rule" => %{"name" => "Renamed Rule", "position" => Integer.to_string(rule.position)}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Rule, rule.id).name == "Original Rule Name"
    end
  end

  describe "PUT /rules/:position (update)" do
    test "updates the rule as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      rule = rule_fixture(%{name: "Original Rule Name"})

      conn =
        put(conn, ~p"/rules/#{rule}", %{
          "rule" => %{
            "name" => "Put Renamed Rule",
            "position" => Integer.to_string(rule.position)
          }
        })

      assert redirected_to(conn) == ~p"/rules/#{rule}"
      assert Repo.get(Rule, rule.id).name == "Put Renamed Rule"
    end
  end
end
