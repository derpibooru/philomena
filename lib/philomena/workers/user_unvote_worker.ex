defmodule Philomena.UserUnvoteWorker do
  alias Philomena.UserDownvoteWipe

  def perform(user_id, votes_and_faves_too?) do
    UserDownvoteWipe.perform(user_id, votes_and_faves_too?)
  end
end
