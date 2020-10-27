defmodule Philomena.Config do
  def get(key) do
    Application.get_env(:philomena, :config)[key]
  end
end
