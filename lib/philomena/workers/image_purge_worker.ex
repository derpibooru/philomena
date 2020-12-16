defmodule Philomena.ImagePurgeWorker do
  alias Philomena.Images

  def perform(files) do
    Images.perform_purge(files)
  end
end
