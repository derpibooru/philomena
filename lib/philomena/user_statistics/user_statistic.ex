defmodule Philomena.UserStatistics.UserStatistic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_statistics" do
    belongs_to :user, Philomena.Users.User
    field :day, :integer, default: 0
    field :uploads, :integer, default: 0
    field :votes_cast, :integer, default: 0
    field :comments_posted, :integer, default: 0
    field :metadata_updates, :integer, default: 0
    field :images_favourited, :integer, default: 0
    field :forum_posts, :integer, default: 0
  end

  @doc false
  def changeset(user_statistic, attrs) do
    user_statistic
    |> cast(attrs, [])
    |> validate_required([])
  end
end
