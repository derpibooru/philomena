defmodule Philomena.UserStatistics.UserStatistic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  @primary_key false

  schema "user_statistics" do
    belongs_to :user, User, primary_key: true
    field :day, :date, primary_key: true
    field :images_count, :integer, default: 0
    field :image_votes_count, :integer, default: 0
    field :comments_count, :integer, default: 0
    field :metadata_updates_count, :integer, default: 0
    field :image_faves_count, :integer, default: 0
    field :posts_count, :integer, default: 0
    field :topics_count, :integer, default: 0
  end

  @doc false
  def changeset(user_statistic, attrs) do
    user_statistic
    |> cast(attrs, [
      :images_count,
      :image_votes_count,
      :comments_count,
      :metadata_updates_count,
      :image_faves_count,
      :posts_count,
      :topics_count
    ])
  end
end
