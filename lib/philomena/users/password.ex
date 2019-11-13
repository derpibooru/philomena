defmodule Philomena.Users.Password do
  def hash_pwd_salt(password, opts \\ []) do
    Bcrypt.hash_pwd_salt(<<password::binary, password_pepper()::binary>>, opts)
  end

  def verify_pass(password, stored_hash) do
    Bcrypt.verify_pass(<<password::binary, password_pepper()::binary>>, stored_hash)
  end

  defp password_pepper do
    Application.get_env(:philomena, :password_pepper)
  end
end
