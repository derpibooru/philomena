defmodule Philomena.UserStatistics do
  @moduledoc """
  The UserStatistics context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserStatistics.UserStatistic
  alias Philomena.Users.User

  @doc """
  Updates a user_statistic.

  ## Examples

      iex> update_user_statistic(user_statistic, %{field: new_value})
      {:ok, %UserStatistic{}}

      iex> update_user_statistic(user_statistic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def inc_stat(user, action, amount \\ 1)

  def inc_stat(nil, _action, _amount), do: {:ok, nil}

  def inc_stat(%{id: user_id}, action, amount)
      when action in [
             :uploads,
             :images_favourited,
             :comments_posted,
             :votes_cast,
             :metadata_updates,
             :forum_posts
           ] do
    now =
      DateTime.utc_now()
      |> DateTime.to_unix(:second)
      |> div(86400)

    user = User |> where(id: ^user_id)
    action_count = String.to_existing_atom("#{action}_count")

    run = fn ->
      Repo.update_all(user, inc: [{action_count, amount}])

      Repo.insert(
        Map.put(%UserStatistic{day: now, user_id: user_id}, action, amount),
        on_conflict: [inc: [{action, amount}]],
        conflict_target: [:day, :user_id]
      )
    end

    Repo.transaction(run)
  end
end
