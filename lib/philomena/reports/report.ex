defmodule Philomena.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset
  import Philomena.MarkdownWriter

  alias Philomena.Users.User

  schema "reports" do
    belongs_to :user, User
    belongs_to :admin, User

    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :reason, :string
    field :reason_md, :string
    field :state, :string, default: "open"
    field :open, :boolean, default: true

    # fixme: rails polymorphic relation
    field :reportable_id, :integer
    field :reportable_type, :string

    field :reportable, :any, virtual: true
    field :category, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [])
    |> validate_required([])
  end

  # Ensure that the report is not currently claimed before
  # attempting to claim
  def claim_changeset(report, user) do
    change(report)
    |> validate_inclusion(:admin_id, [])
    |> put_change(:admin_id, user.id)
    |> put_change(:open, true)
    |> put_change(:state, "in_progress")
  end

  def unclaim_changeset(report) do
    change(report)
    |> put_change(:admin_id, nil)
    |> put_change(:open, true)
    |> put_change(:state, "open")
  end

  def close_changeset(report, user) do
    change(report)
    |> put_change(:admin_id, user.id)
    |> put_change(:open, false)
    |> put_change(:state, "closed")
  end

  @doc false
  def creation_changeset(report, attrs, attribution) do
    report
    |> cast(attrs, [:category, :reason])
    |> validate_length(:reason, max: 10_000, count: :bytes)
    |> merge_category()
    |> change(attribution)
    |> validate_required([
      :reportable_id,
      :reportable_type,
      :category,
      :reason,
      :ip,
      :fingerprint,
      :user_agent
    ])
  end

  defp merge_category(changeset) do
    reason = get_field(changeset, :reason)
    category = get_field(changeset, :category)
    new_reason = joiner(category, reason)

    changeset
    |> change(reason: new_reason)
    |> put_markdown(%{reason: new_reason}, :reason, :reason_md)
  end

  defp joiner(category, ""), do: category
  defp joiner(category, nil), do: category
  defp joiner(category, reason), do: category <> ": " <> reason
end
