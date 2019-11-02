defmodule PowMultiFactor.Plug do
  @moduledoc """
  Plug helper methods.
  """

  alias Plug.Crypto
  alias Pow.Plug
  alias Pow.Config

  def mfa_authorized?(conn, config) do
    user = Plug.current_user(conn)

    if user.otp_required_for_login do
      secret = user.__struct__.otp_secret(user)
      totp = Elixir2fa.generate_totp(secret)

      Crypto.secure_compare(totp, conn.params)
    else
      true
    end
  end

  def assign_mfa(conn, config) do
    user = Plug.current_user(conn)
    repo = Config.repo!(config)

    if user.encrypted_otp_secret in [nil, ""] do
      {:ok, user} = 
        user.__struct__.put_otp_secret(Elixir2fa.random_secret())
        |> repo.update()

      user
    else
      user
    end
  end
end
