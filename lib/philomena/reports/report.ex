defmodule Philomena.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Attribution.Actor
  alias Philomena.Users.User
  alias Philomena.Rules.Rule
  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Posts.Post
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery

  # Foreign key columns naming the report's target. Exactly one is set on a
  # live report; all are NULL on an orphaned report whose target was deleted.
  @target_columns [
    :image_id,
    :comment_id,
    :post_id,
    :reported_user_id,
    :commission_id,
    :conversation_id,
    :gallery_id
  ]

  @type t :: %__MODULE__{}

  schema "reports" do
    belongs_to :user, User
    belongs_to :admin, User
    belongs_to :rule, Rule, on_replace: :nilify

    belongs_to :image, Image
    belongs_to :comment, Comment
    belongs_to :post, Post
    belongs_to :reported_user, User
    belongs_to :commission, Commission
    belongs_to :conversation, Conversation
    belongs_to :gallery, Gallery

    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :reason, :string
    field :state, :string, default: "open"
    field :open, :boolean, default: true
    field :system, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc """
  The list of foreign key columns naming a report's target.
  """
  def target_columns, do: @target_columns

  @doc """
  Preloads to apply to the target associations so downstream views and the
  search index have the nested data they expect.
  """
  def target_preloads do
    [
      :reported_user,
      image: [:user, :sources, tags: :aliases],
      comment: [:user, image: [:sources, tags: :aliases]],
      post: [:user, topic: :forum],
      commission: [:user],
      conversation: [:from, :to],
      gallery: [:user]
    ]
  end

  @doc false
  def changeset(report, attrs \\ %{}) do
    report
    |> cast(attrs, [])
    |> validate_required([])
  end

  def conversion_changeset(report, attrs, rule) do
    report
    |> cast(attrs, [:reason])
    |> put_assoc(:rule, rule)
    |> validate_required([:reason])
  end

  def claim_changeset(report, user) do
    change(report)
    |> validate_open()
    |> validate_unclaimed()
    |> put_change(:admin_id, user.id)
    |> put_change(:open, true)
    |> put_change(:state, "in_progress")
  end

  def unclaim_changeset(report, _user) do
    change(report)
    |> validate_open()
    |> validate_claimed()
    |> put_change(:admin_id, nil)
    |> put_change(:open, true)
    |> put_change(:state, "open")
  end

  def close_changeset(report, user) do
    change(report)
    |> validate_open()
    |> put_change(:admin_id, user.id)
    |> put_change(:open, false)
    |> put_change(:state, "closed")
  end

  defp validate_open(changeset) do
    if get_field(changeset, :open) do
      changeset
    else
      add_error(changeset, :state, "must be open")
    end
  end

  defp validate_claimed(changeset) do
    if is_nil(get_field(changeset, :admin_id)) do
      add_error(changeset, :admin_id, "was not claimed")
    else
      changeset
    end
  end

  defp validate_unclaimed(changeset) do
    if is_nil(get_field(changeset, :admin_id)) do
      changeset
    else
      add_error(changeset, :admin_id, "has already been claimed")
    end
  end

  @doc false
  def creation_changeset(report, attrs, %Actor{} = actor, rule) do
    report
    |> cast(attrs, [:reason, :user_agent])
    |> put_assoc(:rule, rule)
    |> validate_length(:reason, max: 10_000, count: :bytes)
    |> validate_length(:user_agent, max: 1000, count: :bytes)
    |> change(Actor.to_changes(actor))
    |> validate_required([
      :reason,
      :ip,
      :fingerprint,
      :user_agent
    ])
    |> validate_target()
  end

  def system_creation_changeset(report, attrs, %Actor{} = actor, %Rule{} = rule) do
    report
    |> creation_changeset(attrs, actor, rule)
    |> change(system: true)
  end

  def user_creation_changeset(report, attrs, %Actor{} = actor, %Rule{} = rule) do
    report
    |> creation_changeset(attrs, actor, rule)
    |> validate_rule()
  end

  @doc false
  def fetch_rule_id(attrs) when not is_map(attrs), do: {:error, :not_found}

  def fetch_rule_id(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:rule_id])
    |> validate_required(:rule_id)
    |> apply_action(:create)
    |> case do
      {:ok, %{rule_id: rule_id}} ->
        {:ok, rule_id}

      _ ->
        {:error, :not_found}
    end
  end

  # A report must reference exactly one target on creation.
  defp validate_target(changeset) do
    set = Enum.count(@target_columns, &(not is_nil(get_field(changeset, &1))))

    if set == 1 do
      changeset
    else
      add_error(changeset, :target, "must reference exactly one target")
    end
  end

  defp validate_rule(changeset) do
    case get_assoc(changeset, :rule, :struct) do
      nil -> add_error(changeset, :rule_id, "is invalid")
      %Rule{internal: true} -> add_error(changeset, :rule_id, "is internal")
      _ -> changeset
    end
  end
end
