defmodule Philomena.UserEraseWorker do
  alias Philomena.Users.Eraser
  alias Philomena.Users

  def perform(user_id, moderator_id) do
    moderator = Users.fetch_user_for_erase!(moderator_id)
    user = Users.fetch_user_for_worker!(user_id)

    Eraser.erase_permanently!(user, moderator)
  end
end
