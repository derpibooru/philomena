defmodule Philomena.Rules do
  @moduledoc """
  Rule publication, version history, and authorized rule administration.

  Public rule routes use the stable position as their locator. Locator parsing,
  lookup, and authorization share the same missing-before-forbidden contract as
  ID-based contexts.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.IntegerId
  alias Philomena.Authorization
  alias Philomena.Loader
  alias Philomena.Repo

  alias Philomena.Attribution.Actor
  alias Philomena.Rules.Rule
  alias Philomena.Rules.RuleVersion
  alias Philomena.Users.User

  @doc """
  Returns every rule, including hidden and internal ones, ordered by position.

  ## Examples

      iex> list_rules()
      [%Rule{name: "Rule #0", ...}, ..., %Rule{name: "Legacy", ...}]

  """
  @spec list_rules() :: [Rule.t()]
  def list_rules do
    Repo.all(from r in Rule, order_by: [asc: r.position])
  end

  defp list_visible_rules do
    Repo.all(
      from r in Rule,
        where: r.hidden == false and r.internal == false,
        order_by: [asc: r.position]
    )
  end

  @doc """
  Returns a list of all the reportable rules.

  ## Examples

      iex> list_reportable_rules()
      [%Rule{name: "Rule #0", ...}, ...]

  """
  @spec list_reportable_rules() :: [Rule.t()]
  def list_reportable_rules do
    Repo.all(
      from r in Rule,
        where: r.internal == false,
        order_by: [asc: r.position]
    )
  end

  @doc """
  Gets a single rule. Returns nil if the rule does not exist.

  ## Examples

      iex> fetch_rule(123)
      {:ok, %Rule{}}

      iex> fetch_rule(456)
      {:error, not_found}

  """
  @spec fetch_rule(Loader.integer_id()) :: {:ok, Rule.t()} | {:error, :not_found}
  def fetch_rule(id) do
    Loader.fetch(Rule, id)
  end

  @doc """
  Loads a rule by its name.

  ## Examples

      iex> fetch_rule_by_name("Rule #0")
      {:ok, %Rule{name: "Rule #0", ...}}

      iex> fetch_rule_by_name("Nonexistent Rule")
      {:error, :not_found}

  """
  @spec fetch_rule_by_name(String.t()) :: Loader.fetch_result(Rule.t())
  def fetch_rule_by_name(name) do
    Rule
    |> where(name: ^name)
    |> Loader.one()
  end

  @doc """
  Returns a list of all rule versions for a given rule.

  ## Examples

      iex> list_rule_versions(rule)
      [%RuleVersion{...}, ...]

  """
  @spec list_rule_versions(Rule.t()) :: [RuleVersion.t()]
  def list_rule_versions(%Rule{} = rule) do
    Repo.all(
      from rv in RuleVersion,
        where: rv.rule_id == ^rule.id,
        order_by: [desc: rv.created_at, desc: rv.id],
        preload: [:user]
    )
  end

  defp create_rule_version(%Rule{} = rule, %User{} = user) do
    %RuleVersion{}
    |> RuleVersion.changeset(%{
      name: rule.name,
      title: rule.title,
      description: rule.description,
      short_description: rule.short_description,
      example: rule.example,
      rule_id: rule.id,
      user_id: user.id
    })
    |> Repo.insert()
  end

  defp create_rule_version(%Rule{} = rule, nil) do
    create_rule_version(rule, %User{id: nil})
  end

  defp insert_rule(attrs) do
    %Rule{}
    |> Rule.changeset(attrs)
    |> Repo.insert()
  end

  defp create_rule_with_version(attrs, user) do
    Repo.transact(fn ->
      with {:ok, rule} <- insert_rule(attrs),
           {:ok, rule_version} <- create_rule_version(rule, user) do
        {:ok, [rule, rule_version]}
      end
    end)
  end

  defp save_rule(%Rule{} = rule, attrs) do
    rule
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  defp update_rule_with_version(%Rule{} = rule, user, attrs) do
    Repo.transact(fn ->
      with {:ok, updated_rule} <- save_rule(rule, attrs),
           {:ok, rule_version} <- create_rule_version(updated_rule, user) do
        {:ok, [updated_rule, rule_version]}
      end
    end)
  end

  # Returns an `%Ecto.Changeset{}` for tracking rule changes.
  defp change_rule(%Rule{} = rule, attrs \\ %{}) do
    Rule.changeset(rule, attrs)
  end

  defp load_authorized_rule(actor, position, action) do
    with {:ok, position} <- Loader.parse_id(position) do
      Rule
      |> where(position: ^position)
      |> Loader.one_and_authorize(actor, action)
    end
  end

  @doc """
  Returns the rules `actor` may see, ordered by position.

  A viewer who may edit rules sees every rule; everyone else sees only the
  visible (non-hidden, non-internal) rules.
  """
  @spec list_rules_for(Actor.t()) :: [Rule.t()]
  def list_rules_for(%Actor{} = actor) do
    case authorize(actor, :edit, Rule) do
      :ok -> list_rules()
      {:error, :unauthorized} -> list_visible_rules()
    end
  end

  @doc """
  Loads the rule at `position` for `actor` to be shown.

  A malformed or absent position is not found for every actor. A real hidden or
  internal rule is unauthorized unless the actor has rule-edit permission.

  ## Examples

      iex> show_rule(actor, "1")
      {:ok, %Rule{}}

      iex> show_rule(actor, "not-a-position")
      {:error, :not_found}
  """
  @spec show_rule(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Rule.t()} | {:error, :not_found | :unauthorized}
  def show_rule(%Actor{} = actor, position) do
    load_authorized_rule(actor, position, :show)
  end

  @doc """
  Prepares a new rule on behalf of `actor`.

  Rejects a banned actor and authorizes `:new` before returning the changeset.

  ## Examples

      iex> new_rule(admin_actor)
      {:ok, %Ecto.Changeset{}}

      iex> new_rule(user_actor)
      {:error, :unauthorized}
  """
  @spec new_rule(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | Authorization.write_error()
  def new_rule(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Rule) do
      {:ok, change_rule(%Rule{})}
    end
  end

  @doc """
  Creates a rule (with its initial version) on behalf of `actor` from `attrs`.

  Verifies write access and authorizes `:create`. The rule and its initial
  version are inserted in one transaction.

  ## Examples

      iex> create_rule(admin_actor, %{name: "Rule #1", position: 1})
      {:ok, [%Rule{}, %RuleVersion{}]}

      iex> create_rule(user_actor, %{name: "Rule #1", position: 1})
      {:error, :unauthorized}

  """
  @spec create_rule(Actor.t(), map()) ::
          {:ok, [Rule.t() | RuleVersion.t()]}
          | {:error, Ecto.Changeset.t()}
          | Authorization.write_error()
  def create_rule(%Actor{} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Rule) do
      create_rule_with_version(attrs, actor.user)
    end
  end

  @doc """
  Loads the rule at `position` for `actor` to edit.

  Rejects a banned actor before safely loading the position and authorizing
  `:edit` on the real rule.

  ## Examples

      iex> edit_rule(admin_actor, "1")
      {:ok, {%Rule{}, %Ecto.Changeset{}}}

      iex> edit_rule(admin_actor, "missing")
      {:error, :not_found}

  """
  @spec edit_rule(Actor.t(), IntegerId.integer_id()) ::
          {:ok, {Rule.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_rule(%Actor{} = actor, position) do
    with :ok <- verify_not_banned(actor),
         {:ok, rule} <- load_authorized_rule(actor, position, :edit) do
      {:ok, {rule, change_rule(rule)}}
    end
  end

  @doc """
  Updates the rule at `position` (with a new version), on behalf of `actor`, from
  `attrs`.

  Verifies write access before safely loading the position and authorizing
  `:update`. The update and its version are stored in one transaction. A
  validation failure carries the original rule for form rendering.

  ## Examples

      iex> update_rule(admin_actor, "1", %{title: "Be excellent"})
      {:ok, [%Rule{}, %RuleVersion{}]}

      iex> update_rule(admin_actor, "1", %{name: ""})
      {:error, {%Rule{}, %Ecto.Changeset{}}}

  """
  @spec update_rule(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, [Rule.t() | RuleVersion.t()]}
          | {:error, {Rule.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def update_rule(%Actor{} = actor, position, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, rule} <- load_authorized_rule(actor, position, :update) do
      case update_rule_with_version(rule, actor.user, attrs) do
        {:ok, [updated_rule, rule_version]} -> {:ok, [updated_rule, rule_version]}
        {:error, changeset} -> {:error, {rule, changeset}}
      end
    end
  end
end
