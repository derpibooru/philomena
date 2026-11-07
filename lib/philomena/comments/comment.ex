defmodule Philomena.Comments.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Attribution.Actor
  alias Philomena.Images.Image
  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.Schema.Approval

  @type t :: %__MODULE__{}

  schema "comments" do
    belongs_to :user, User
    belongs_to :image, Image
    belongs_to :deleted_by, User
    has_many :reports, Report

    field :body, :string
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :anonymous, :boolean, default: false
    field :hidden_from_users, :boolean, default: false
    field :edit_reason, :string
    field :edited_at, :utc_datetime
    field :deletion_reason, :string, default: ""
    field :destroyed_content, :boolean, default: false
    field :approved, :boolean, default: true
    field :became_unapproved?, :boolean, virtual: true, default: false
    field :became_approved?, :boolean, virtual: true, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def creation_changeset(comment, attrs, %Actor{} = actor) do
    comment
    |> cast(attrs, [:body, :anonymous])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(Actor.to_changes(actor))
    |> Approval.maybe_put_approval(actor.user, :external_links)
  end

  def changeset(comment, attrs \\ %{}, edited_at \\ nil) do
    changeset =
      comment
      |> cast(attrs, [:body, :edit_reason])
      |> put_change(:edited_at, edited_at)
      |> validate_required([:body])
      |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
      |> validate_length(:edit_reason, max: 70, count: :bytes)
      |> Approval.maybe_put_approval(comment.user, :external_links)

    put_change(
      changeset,
      :became_approved?,
      not comment.approved and get_field(changeset, :approved)
    )
  end

  def hide_changeset(comment, attrs, user) do
    comment
    |> cast(attrs, [:deletion_reason])
    |> put_change(:hidden_from_users, true)
    |> put_change(:deleted_by_id, user.id)
    |> validate_required([:deletion_reason])
  end

  def unhide_changeset(comment) do
    change(comment)
    |> validate_undestroyed()
    |> put_change(:hidden_from_users, false)
    |> put_change(:deleted_by_id, nil)
    |> put_change(:deletion_reason, "")
  end

  def destroy_changeset(comment) do
    change(comment)
    |> validate_hidden()
    |> validate_undestroyed()
    |> put_change(:destroyed_content, true)
    |> put_change(:body, "")
  end

  @doc false
  def approve_changeset(comment) do
    comment
    |> change()
    |> validate_undestroyed()
    |> Approval.approve_changeset()
  end

  defp validate_hidden(changeset) do
    if not get_field(changeset, :hidden_from_users) do
      add_error(changeset, :destroyed_content, "cannot be set while comment is visible")
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
