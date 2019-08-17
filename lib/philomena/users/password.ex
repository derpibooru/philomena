defmodule Philomena.Users.Password do
  def hash_pwd_salt(password, opts \\ []) do
    pepper = Application.get_env(:philomena, :password_pepper)

    Bcrypt.hash_pwd_salt(<<password::binary, pepper::binary>>, opts)
  end

  def verify_pass(password, stored_hash) do
    pepper = Application.get_env(:philomena, :password_pepper)

    Bcrypt.verify_pass(<<password::binary, pepper::binary>>, stored_hash)
  end
end
