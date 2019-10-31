defmodule PowMultiFactor.Plug do
  @moduledoc """
  Plug helper methods.
  """

  alias Pow.Plug
  #alias PowMultiFactor.Ecto.Context

  def mfa_unauthorized?(conn) do
    user = Plug.current_user(conn)

    if user.otp_required_for_login do
      true
    else
      false
    end
  end

  #defp otp_secret(user) do

  #end

  #defp otp_shared_key do
  #  Application.get_env
  #end
end
