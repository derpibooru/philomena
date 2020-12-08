defmodule Philomena.UserRenameWorker do
  alias Philomena.Users

  def perform(old_name, new_name) do
    Users.perform_rename(old_name, new_name)
  end
end
