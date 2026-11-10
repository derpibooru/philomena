defmodule Philomena.UserWipeWorker do
  alias Philomena.Users.UserWipe

  def perform(user_id) do
    UserWipe.perform(user_id)
  end
end
