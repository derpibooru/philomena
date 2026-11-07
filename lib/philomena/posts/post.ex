defmodule Philomena.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Attribution.Actor
  alias Philomena.Users.User
  alias Philomena.Topics.Topic
  alias Philomena.Reports.Report
  alias Philomena.Schema.Approval

  @type t :: %__MODULE__{}

  schema "posts" do
    belongs_to :user, User
    belongs_to :topic, Topic
    belongs_to :deleted_by, User
    has_many :reports, Report

    field :body, :string
    field :edit_reason, :string
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :topic_position, :integer
    field :hidden_from_users, :boolean, default: false
    field :anonymous, :boolean, default: false
    field :edited_at, :utc_datetime
    field :deletion_reason, :string, default: ""
    field :destroyed_content, :boolean, default: false
    field :approved, :boolean, default: true
    field :became_unapproved?, :boolean, virtual: true, default: false
    field :became_approved?, :boolean, virtual: true, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs, edited_at \\ nil) do
    changeset =
      post
      |> cast(attrs, [:body, :edit_reason])
      |> put_change(:edited_at, edited_at)
      |> validate_required([:body])
      |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
      |> validate_length(:edit_reason, max: 70, count: :bytes)
      |> Approval.maybe_put_approval(post.user, :external_links)

    put_change(
      changeset,
      :became_approved?,
      not post.approved and get_field(changeset, :approved)
    )
  end

  @doc false
  def creation_changeset(post, attrs, %Actor{} = actor) do
    post
    |> cast(attrs, [:body, :anonymous])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(Actor.to_changes(actor))
    |> Approval.maybe_put_approval(actor.user, :external_links)
  end

  @doc false
  def topic_creation_changeset(post, attrs, %Actor{} = actor, anonymous?) do
    post
    |> change(anonymous: anonymous?)
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(Actor.to_changes(actor))
    |> change(topic_position: 0)
    |> Approval.maybe_put_approval(actor.user, :external_links)
  end

  def hide_changeset(post, attrs, user) do
    post
    |> cast(attrs, [:deletion_reason])
    |> put_change(:hidden_from_users, true)
    |> put_change(:deleted_by_id, user.id)
    |> validate_required([:deletion_reason])
  end

  def unhide_changeset(post) do
    change(post)
    |> validate_undestroyed()
    |> put_change(:hidden_from_users, false)
    |> put_change(:deleted_by_id, nil)
    |> put_change(:deletion_reason, "")
  end

  def destroy_changeset(post) do
    post
    |> change()
    |> validate_hidden()
    |> validate_undestroyed()
    |> put_change(:destroyed_content, true)
    |> put_change(:body, "")
  end

  @doc false
  def approve_changeset(post) do
    post
    |> change()
    |> validate_undestroyed()
    |> Approval.approve_changeset()
  end

  defp validate_hidden(changeset) do
    if not get_field(changeset, :hidden_from_users) do
      add_error(changeset, :destroyed_content, "cannot be set while post is visible")
    else
      changeset
    end
  end

  defp validate_undestroyed(changeset) do
    if get_field(changeset, :destroyed_content) do
      add_error(changeset, :destroyed_content, "has already been destroyed")
    else
      changeset
    end
  end
end
