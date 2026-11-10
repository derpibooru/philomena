defmodule PhilomenaWeb.RuleController do
  use PhilomenaWeb, :controller

  alias Philomena.Rules
  alias PhilomenaWeb.MarkdownRenderer

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    rules =
      conn.assigns.actor
      |> Rules.list_rules_for()
      |> Enum.map(&render_rule(&1, conn))

    last_updated_at =
      rules
      |> Enum.map(& &1.updated_at)
      |> Enum.max(DateTime, fn -> nil end)

    render(conn, :index, rules: rules, last_updated_at: last_updated_at)
  end

  def new(conn, _params) do
    with {:ok, changeset} <- Rules.new_rule(conn.assigns.actor) do
      render(conn, :new, changeset: changeset)
    end
  end

  def create(conn, %{"rule" => rule_params}) do
    case Rules.create_rule(conn.assigns.actor, rule_params) do
      {:ok, [rule, _version]} ->
        conn
        |> put_flash(:info, "Rule created successfully.")
        |> redirect(to: ~p"/rules/#{rule}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def show(conn, %{"id" => id}) do
    case Rules.show_rule(conn.assigns.actor, id) do
      {:ok, rule} ->
        rule = render_rule(rule, conn)

        versions =
          rule
          |> Rules.list_rule_versions()
          |> generate_diff()

        render(conn, :show, rule: rule, versions: versions)

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, {rule, changeset}} <- Rules.edit_rule(conn.assigns.actor, id) do
      render(conn, :edit, rule: rule, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    case Rules.update_rule(conn.assigns.actor, id, rule_params) do
      {:ok, [rule, _version]} ->
        conn
        |> put_flash(:info, "Rule updated successfully.")
        |> redirect(to: ~p"/rules/#{rule}")

      {:error, {rule, %Ecto.Changeset{} = changeset}} ->
        render(conn, :edit, rule: rule, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  defp render_rule(rule, conn) do
    %{
      rule
      | description:
          if(rule.description != "",
            do: MarkdownRenderer.render_unsafe(rule.description, conn),
            else: ""
          ),
        example:
          if(rule.example != "",
            do: MarkdownRenderer.render_unsafe(rule.example, conn),
            else: ""
          )
    }
  end

  defp diff_field(field, previous, next) do
    old = Map.get(previous, field)
    new = Map.get(next, field)

    if old == new do
      nil
    else
      MarkdownRenderer.render_diff(old, new)
    end
  end

  defp compare_versions(previous, next) do
    %{
      description: diff_field(:description, previous, next),
      example: diff_field(:example, previous, next)
    }
  end

  defp generate_diff(versions) when length(versions) < 2 do
    []
  end

  defp generate_diff(versions) do
    versions
    # Reverse to have oldest first
    |> Enum.reverse()
    |> Enum.map_reduce(nil, fn version, previous ->
      diffs =
        if previous do
          compare_versions(previous, version)
        else
          %{
            description: nil,
            example: nil
          }
        end

      {%{version | differences: diffs, previous: previous}, version}
    end)
    |> elem(0)
    # Reverse back to have newest first
    |> Enum.reverse()
  end
end
