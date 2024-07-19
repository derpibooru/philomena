defmodule Philomena.UserEraseWorker do
  alias Philomena.Users.Eraser
  alias Philomena.Users

  def perform(user_id, moderator_id) do
    moderator = Users.get_user!(moderator_id)
    user = Users.get_user!(user_id)

    Eraser.erase_permanently!(user, moderator)
  end
end
