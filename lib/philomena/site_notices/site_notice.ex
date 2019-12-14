defmodule Philomena.SiteNotices.SiteNotice do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  import Philomena.Schema.Time

  schema "site_notices" do
    belongs_to :user, User

    field :title, :string
    field :text, :string, default: ""
    field :link, :string, default: ""
    field :link_text, :string, default: ""
    field :live, :boolean, default: true
    field :start_date, :utc_datetime
    field :finish_date, :utc_datetime

    field :start_time, :string, virtual: true
    field :finish_time, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(site_notice, attrs) do
    site_notice
    |> cast(attrs, [])
    |> propagate_time(:start_date, :start_time)
    |> propagate_time(:finish_date, :finish_time)
    |> validate_required([])
  end

  def save_changeset(site_notice, attrs) do
    site_notice
    |> cast(attrs, [:title, :text, :link, :link_text, :live, :start_time, :finish_time])
    |> assign_time(:start_time, :start_date)
    |> assign_time(:finish_time, :finish_date)
  end
end
