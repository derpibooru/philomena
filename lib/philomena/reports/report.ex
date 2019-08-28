defmodule Philomena.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reports" do
    belongs_to :user, Philomena.Users.User
    belongs_to :admin, Philomena.Users.User

    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :reason, :string
    field :state, :string, default: "open"
    field :open, :boolean, default: true

    # fixme: rails polymorphic relation
    field :reportable_id, :integer
    field :reportable_type, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [])
    |> validate_required([])
  end
end
