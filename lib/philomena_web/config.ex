defmodule PhilomenaWeb.Config do
  @moduledoc """
  Runtime accessors for web configuration.
  """

  def vite_hmr?, do: Application.get_env(:philomena, :vite_reload, false)
  def csp_relax_on_error?, do: Application.get_env(:philomena, :csp_relax_on_error, false)
end
